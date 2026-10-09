"""Parent-only privacy jobs; no provider data or safety fragments in exports."""
import json
import hmac
import secrets
import time
import sqlite3
from pathlib import Path
from backend.domain import DomainError, digest, password_matches, payload_hash, uid, now

class PrivacyService:
    def __init__(self, repo):
        self.repo, self.db = repo, repo.db

    def durable_ledger(self):
        if self.repo.database_path==':memory:':raise DomainError('DURABLE_LEDGER_REQUIRED',503)
        path=Path(self.repo.database_path+'.deletion-ledger.sqlite')
        connection=sqlite3.connect(path,timeout=10)
        path.chmod(0o600)
        connection.execute('PRAGMA synchronous=FULL')
        connection.execute('CREATE TABLE IF NOT EXISTS deletions (id TEXT PRIMARY KEY,family_id TEXT NOT NULL,child_id TEXT,occurred_at TEXT NOT NULL)')
        return connection

    def reconcile(self):
        if not Path(self.repo.database_path+'.deletion-ledger.sqlite').exists():return
        ledger=self.durable_ledger()
        try:
            for row in ledger.execute('SELECT id,family_id,child_id,occurred_at FROM deletions'):
                existing=self.db.execute('SELECT applied_at FROM deletion_ledger WHERE id=?',(row[0],)).fetchone()
                if existing and existing[0]:continue
                with self.db:
                    self.db.execute('INSERT OR IGNORE INTO deletion_ledger VALUES (?,?,?,?,NULL)',row)
                    self.apply_deletion(row[1],row[2])
                    self.db.execute('UPDATE deletion_ledger SET applied_at=? WHERE id=?',(now(),row[0]))
                    self.db.execute("UPDATE privacy_jobs SET state='completed',completed_at=? WHERE id=?",(now(),row[0]))
        finally:ledger.close()

    def persist_deletion(self,row):
        ledger=self.durable_ledger()
        try:
            with ledger:ledger.execute('INSERT OR IGNORE INTO deletions VALUES (?,?,?,?)',(row['id'],row['family_id'],row['child_id'],row['created_at']))
        finally:ledger.close()

    def parent(self, auth):
        if auth['child_id']: raise DomainError('PARENT_AUTH_REQUIRED',403)

    def reauthenticate(self, auth, data):
        self.parent(auth)
        purpose = data.get('purpose')
        if purpose not in ('export','deletion'): raise DomainError('VALIDATION_FAILED')
        scope='reauth:'+auth['family_id']
        self.repo.throttle(scope)
        row=self.db.execute('SELECT password_hash FROM families WHERE id=?',(auth['family_id'],)).fetchone()
        password=data.get('password')
        if not row or not isinstance(password,str) or not 10<=len(password)<=128 or not password_matches(password,row[0]):
            self.repo.fail_auth(scope)
            raise DomainError('REAUTH_REQUIRED',401)
        token=secrets.token_urlsafe(32)
        with self.db:
            self.db.execute('DELETE FROM auth_failures WHERE scope=?',(scope,))
            self.db.execute('DELETE FROM privacy_reauth WHERE expires_at<=?',(time.time(),))
            self.db.execute('INSERT INTO privacy_reauth VALUES (?,?,?,?)',(digest(token),auth['token_hash'],purpose,time.time()+300))
        return {'reauth_token':token,'expires_in':300,'purpose':purpose}

    def proof(self, auth, data, purpose):
        token=data.get('reauth_token')
        if not isinstance(token,str):raise DomainError('REAUTH_REQUIRED',401)
        row=self.db.execute('SELECT * FROM privacy_reauth WHERE token_hash=?',(digest(token),)).fetchone()
        if not row or row['session_hash']!=auth['token_hash'] or row['purpose']!=purpose or row['expires_at']<=time.time():
            raise DomainError('REAUTH_REQUIRED',401)
        self.db.execute('DELETE FROM privacy_reauth WHERE token_hash=?',(digest(token),))

    def replay_deletion(self,token,data,key):
        if not isinstance(key,str):return None
        row=self.db.execute('SELECT * FROM privacy_replays WHERE session_hash=? AND operation_key=? AND expires_at>?',(digest(token),key,time.time())).fetchone()
        if not row:return None
        if row['request_hash']!=payload_hash(data):raise DomainError('IDEMPOTENCY_CONFLICT',409)
        return json.loads(row['response'])

    def create(self, auth, data, kind, key):
        self.parent(auth)
        child_id=data.get('child_id')
        if child_id is not None:self.repo.owned_child(auth,child_id)
        if kind=='deletion' and data.get('confirmation')!='DELETE':raise DomainError('DELETION_CONFIRMATION_REQUIRED')
        identity={'child_id':child_id,'confirmation':data.get('confirmation')}
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            prior=self.repo.operation('privacy:'+auth['family_id']+':'+kind,key,identity)
            if prior:return prior
            self.proof(auth,data,kind)
            job_id=uid();receipt=secrets.token_urlsafe(32) if kind=='deletion' and child_id is None else None
            self.db.execute('INSERT INTO privacy_jobs(id,family_id,kind,child_id,state,created_at,receipt_hash) VALUES (?,?,?,?,?,?,?)',
                (job_id,auth['family_id'],kind,child_id,'queued',now(),digest(receipt) if receipt else None))
            if kind=='deletion':
                self.db.execute('INSERT INTO deletion_ledger VALUES (?,?,?,?,NULL)',(job_id,auth['family_id'],child_id,now()))
                if child_id:
                    self.db.execute('DELETE FROM auth_sessions WHERE child_id=?',(child_id,))
                    self.db.execute("UPDATE learning_sessions SET state='cancelled',revision=revision+1 WHERE child_id=? AND state NOT IN ('completed','cancelled')",(child_id,))
                else:
                    self.db.execute('DELETE FROM auth_sessions WHERE family_id=?',(auth['family_id'],))
                    self.db.execute("UPDATE learning_sessions SET state='cancelled',revision=revision+1 WHERE child_id IN (SELECT id FROM children WHERE family_id=?) AND state NOT IN ('completed','cancelled')",(auth['family_id'],))
                self.db.execute('UPDATE privacy_jobs SET artifact=NULL,expires_at=NULL WHERE family_id=? AND kind=\'export\'',(auth['family_id'],))
            result={'id':job_id,'kind':kind,'state':'queued','receipt_token':receipt}
            if receipt:self.db.execute('INSERT INTO privacy_replays VALUES (?,?,?,?,?)',(auth['token_hash'],key,payload_hash(data),json.dumps(result),time.time()+300))
            self.db.execute('INSERT INTO operations VALUES (?,?,?,?)',('privacy:'+auth['family_id']+':'+kind,key,payload_hash(identity),json.dumps(result)))
        return result

    def status(self, auth, job_id=None):
        self.parent(auth)
        if job_id:
            row=self.db.execute('SELECT * FROM privacy_jobs WHERE id=? AND family_id=?',(job_id,auth['family_id'])).fetchone()
            if not row:raise DomainError('NOT_FOUND',404)
            return self.public(row)
        return [self.public(r) for r in self.db.execute('SELECT * FROM privacy_jobs WHERE family_id=? ORDER BY rowid DESC LIMIT 50',(auth['family_id'],))]

    def public(self,row):
        return {k:row[k] for k in ('id','kind','child_id','state','created_at','completed_at','expires_at')}

    def receipt(self,job_id,token):
        row=self.db.execute('SELECT * FROM privacy_jobs WHERE id=? AND kind=\'deletion\'',(job_id,)).fetchone()
        if not row or not row['receipt_hash'] or not hmac.compare_digest(row['receipt_hash'],digest(token)):
            raise DomainError('NOT_FOUND',404)
        return {'id':row['id'],'kind':'deletion','state':row['state'],'completed_at':row['completed_at'],
                'scope':'family','active_data_removed':row['state']=='completed','external_providers_used':False,'backup_sla_confirmed':False}

    def download(self,auth,job_id):
        self.parent(auth)
        row=self.db.execute('SELECT * FROM privacy_jobs WHERE id=? AND family_id=?',(job_id,auth['family_id'])).fetchone()
        if not row:raise DomainError('NOT_FOUND',404)
        if row['kind']!='export' or row['state']!='completed' or not row['artifact'] or row['expires_at']<=time.time():
            raise DomainError('EXPORT_UNAVAILABLE',410)
        return json.loads(row['artifact'])

    def pending_deletion(self,family_id,child_id=None):
        return bool(self.db.execute('SELECT 1 FROM deletion_ledger WHERE family_id=? AND (child_id IS NULL OR child_id=?)',(family_id,child_id)).fetchone())

    def worker(self):
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            self.db.execute('UPDATE privacy_jobs SET artifact=NULL WHERE expires_at<=?',(time.time(),))
            self.db.execute('DELETE FROM privacy_replays WHERE expires_at<=?',(time.time(),))
            row=self.db.execute("SELECT * FROM privacy_jobs WHERE state='queued' ORDER BY rowid LIMIT 1").fetchone()
            if not row:return False
            if row['kind']=='export':
                family=self.db.execute('SELECT locale,timezone,created_at FROM families WHERE id=?',(row['family_id'],)).fetchone()
                if not family or self.pending_deletion(row['family_id'],row['child_id']):
                    self.db.execute("UPDATE privacy_jobs SET state='cancelled',completed_at=? WHERE id=?",(now(),row['id']))
                    return True
                children=[dict(r) for r in self.db.execute('SELECT id,nickname,grade,age_band,instruction_language,avatar FROM children WHERE family_id=?',(row['family_id'],)) if (row['child_id'] is None or r['id']==row['child_id']) and not self.pending_deletion(row['family_id'],r['id'])]
                for child in children:
                    child['sessions']=[dict(r) for r in self.db.execute('SELECT id,lesson_id,state,step,help_level,created_at FROM learning_sessions WHERE child_id=?',(child['id'],))]
                    for session in child['sessions']:
                        session['attempts']=[dict(r) for r in self.db.execute('SELECT evaluation,created_at FROM attempts WHERE session_id=?',(session['id'],))]
                        session['support_events']=[dict(r) for r in self.db.execute('SELECT step,kind,occurred_at FROM learning_evidence WHERE session_id=?',(session['id'],))]
                export={'schema_version':'1.0','exported_at':now(),'family':dict(family),'children':children,
                    'consents':self.repo.consents({'family_id':row['family_id']}),'safety_fragments_included':False,
                    'download_notice':'Удалите скачанную копию с общего устройства после использования.'}
                self.db.execute("UPDATE privacy_jobs SET artifact=?,expires_at=?,state='completed',completed_at=? WHERE id=?",(json.dumps(export,ensure_ascii=False),time.time()+86400,now(),row['id']))
            else:
                self.persist_deletion(row)
                self.apply_deletion(row['family_id'],row['child_id'])
                self.db.execute("UPDATE privacy_jobs SET state='completed',completed_at=? WHERE id=?",(now(),row['id']))
                self.db.execute('UPDATE deletion_ledger SET applied_at=? WHERE id=?',(now(),row['id']))
        return True

    def apply_deletion(self,family_id,child_id=None):
        children=[r[0] for r in self.db.execute('SELECT id FROM children WHERE family_id=?',(family_id,)) if child_id is None or r[0]==child_id]
        for target in children:
            self.db.execute('DELETE FROM learning_evidence WHERE session_id IN (SELECT id FROM learning_sessions WHERE child_id=?)',(target,))
            self.db.execute("DELETE FROM operations WHERE scope IN (SELECT 'hint:'||id FROM learning_sessions WHERE child_id=?)",(target,))
            self.db.execute('DELETE FROM attempts WHERE session_id IN (SELECT id FROM learning_sessions WHERE child_id=?)',(target,))
            self.db.execute('DELETE FROM learning_sessions WHERE child_id=?',(target,))
            self.db.execute('DELETE FROM auth_sessions WHERE child_id=?',(target,))
            self.db.execute('DELETE FROM children WHERE id=?',(target,))
            self.db.execute('DELETE FROM operations WHERE scope=?',('start:'+target,))
        if child_id is None:
            self.db.execute('DELETE FROM auth_sessions WHERE family_id=?',(family_id,))
            self.db.execute('DELETE FROM privacy_reauth WHERE session_hash NOT IN (SELECT token_hash FROM auth_sessions)')
            # Isolated consent/payment/content audits retain opaque IDs; no login or profile metadata.
            self.db.execute('UPDATE families SET login=?,password_hash=?,pin_hash=?,locale=\'ru-KZ\',timezone=\'UTC\' WHERE id=?',('deleted-'+family_id,'disabled','disabled',family_id))
            self.db.execute('DELETE FROM administrator_roles WHERE family_id=?',(family_id,))
            self.db.execute('DELETE FROM content_roles WHERE account_id=?',(family_id,))
            self.db.execute('DELETE FROM operations WHERE scope LIKE ?',('%'+family_id+'%',))
            self.db.execute('DELETE FROM auth_failures WHERE scope IN (?,?)',('pin:'+family_id,'reauth:'+family_id))
            self.db.execute('UPDATE privacy_jobs SET artifact=NULL,receipt_hash=CASE WHEN kind=\'deletion\' THEN receipt_hash ELSE NULL END WHERE family_id=?',(family_id,))
