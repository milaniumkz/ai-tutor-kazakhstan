"""Persistent local engineering slice. No external AI or child-data providers."""
import hashlib
import hmac
import json
import secrets
import sqlite3
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

LOCALES = ('ru-KZ', 'kk-KZ', 'en')
LESSON_ID = 'engineering-addition-v1'
LESSON = {
    'id': LESSON_ID, 'objective_id': 'engineering-add-to-10',
    'curriculum_version_id': 'engineering-fixture-v1', 'grade': 1,
    'subject': 'mathematics', 'status': 'engineering_fixture',
    'official_curriculum': False, 'title': 'Складываем до 10',
    'source': 'Авторское арифметическое задание для инженерной проверки',
    'question': '5 + 2 = ?', 'transfer_question': '4 + 3 = ?',
    'board': {'schema_version': '1.0', 'type': 'counters', 'groups': [5, 2],
              'alt_text': 'Пять кружков и ещё два кружка'},
}

class DomainError(Exception):
    def __init__(self, code, status=400):
        self.code, self.status = code, status
        super().__init__(code)

def uid():
    return str(uuid.uuid4())

def now():
    return datetime.now(timezone.utc).isoformat()

def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()

def password_hash(value):
    salt = secrets.token_hex(16)
    result = hashlib.scrypt(value.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1)
    return salt + ':' + result.hex()

def password_matches(value, encoded):
    salt, expected = encoded.split(':')
    result = hashlib.scrypt(value.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1)
    return hmac.compare_digest(result.hex(), expected)

def payload_hash(data):
    return digest(json.dumps(data, sort_keys=True, ensure_ascii=False))

class Repository:
    def __init__(self, path):
        self.database_path = str(path)
        self.db = sqlite3.connect(path, timeout=10)
        self.db.row_factory = sqlite3.Row
        self.db.executescript((Path(__file__).parent / 'migrations/001_initial.sql').read_text())
        self.db.executescript((Path(__file__).parent / 'migrations/002_tariffs.sql').read_text())
        self.db.executescript((Path(__file__).parent / 'migrations/003_trials.sql').read_text())
        self.db.executescript((Path(__file__).parent / 'migrations/004_content.sql').read_text())
        self.db.executescript((Path(__file__).parent / 'migrations/005_privacy.sql').read_text())
        self.db.executescript((Path(__file__).parent / 'migrations/006_evidence.sql').read_text())
        from backend.content import ContentService
        ContentService(self).seed()
        from backend.privacy import PrivacyService
        PrivacyService(self).reconcile()

    def close(self):
        self.db.close()

    def issue_token(self, family_id, child_id=None):
        token = secrets.token_urlsafe(32)
        self.db.execute('INSERT INTO auth_sessions VALUES (?, ?, ?, ?)',
                        (digest(token), family_id, child_id, time.time() + 900))
        return token

    def register(self, data):
        login, password, pin = (data.get(k) for k in ('login', 'password', 'pin'))
        if not isinstance(login, str) or not 3 <= len(login.strip()) <= 80:
            raise DomainError('VALIDATION_FAILED')
        if not isinstance(password, str) or not 10 <= len(password) <= 128:
            raise DomainError('VALIDATION_FAILED')
        if not isinstance(pin, str) or len(pin) != 6 or not pin.isascii() or not pin.isdigit():
            raise DomainError('VALIDATION_FAILED')
        family_id = uid()
        try:
            with self.db:
                self.db.execute('INSERT INTO families(id, login, password_hash, pin_hash, created_at) VALUES (?,?,?,?,?)',
                    (family_id, login.strip().lower(), password_hash(password), password_hash(pin), now()))
                token = self.issue_token(family_id)
        except sqlite3.IntegrityError:
            raise DomainError('ACCOUNT_UNAVAILABLE', 409) from None
        return {'token': token, 'family_id': family_id, 'contact_verified': False, 'is_admin': False, 'content_roles': []}

    def throttle(self, scope):
        failure = self.db.execute('SELECT * FROM auth_failures WHERE scope=?', (scope,)).fetchone()
        if failure and failure['blocked_until'] > time.time() and failure['count'] >= 5:
            raise DomainError('RATE_LIMITED', 429)

    def fail_auth(self, scope):
        with self.db:
            row = self.db.execute('SELECT * FROM auth_failures WHERE scope=?', (scope,)).fetchone()
            count = row['count'] + 1 if row and row['blocked_until'] > time.time() else 1
            self.db.execute('INSERT OR REPLACE INTO auth_failures VALUES (?,?,?)',
                            (scope, count, time.time() + 900))

    def login(self, data):
        login, password = data.get('login'), data.get('password')
        if not isinstance(login, str) or not isinstance(password, str) or len(password) > 128:
            raise DomainError('AUTH_REQUIRED', 401)
        scope = 'login:' + digest(login.strip().lower())
        self.throttle(scope)
        row = self.db.execute('SELECT * FROM families WHERE login=?', (login.strip().lower(),)).fetchone()
        if not row or row['password_hash']=='disabled' or not password_matches(password, row['password_hash']):
            self.fail_auth(scope)
            raise DomainError('AUTH_REQUIRED', 401)
        with self.db:
            self.db.execute('DELETE FROM auth_failures WHERE scope=?', (scope,))
            token = self.issue_token(row['id'])
        return {'token': token, 'family_id': row['id'], 'contact_verified': False,
                'is_admin': self.is_admin(row['id']),
                'content_roles': [r[0] for r in self.db.execute('SELECT role FROM content_roles WHERE account_id=?',(row['id'],))]}

    def authenticate(self, token, pin=None, parent=False):
        auth = self.db.execute('SELECT * FROM auth_sessions WHERE token_hash=? AND expires_at>?',
                               (digest(token), time.time())).fetchone()
        if not auth:
            raise DomainError('AUTH_REQUIRED', 401)
        from backend.privacy import PrivacyService
        if PrivacyService(self).pending_deletion(auth['family_id'],auth['child_id']):
            raise DomainError('AUTH_REQUIRED',401)
        if parent:
            if auth['child_id']:
                raise DomainError('PARENT_AUTH_REQUIRED', 403)
            scope = 'pin:' + auth['family_id']
            self.throttle(scope)
            family = self.db.execute('SELECT pin_hash FROM families WHERE id=?', (auth['family_id'],)).fetchone()
            if not isinstance(pin, str) or len(pin) != 6 or not password_matches(pin, family['pin_hash']):
                self.fail_auth(scope)
                raise DomainError('PARENT_AUTH_REQUIRED', 403)
            with self.db:
                self.db.execute('DELETE FROM auth_failures WHERE scope=?', (scope,))
        return dict(auth)

    def logout(self, auth):
        with self.db:
            if auth['child_id']:
                self.db.execute('DELETE FROM auth_sessions WHERE token_hash=?',(auth['token_hash'],))
            else:
                self.db.execute('DELETE FROM auth_sessions WHERE family_id=?',(auth['family_id'],))
        return {'logged_out':True}

    def children(self, auth):
        from backend.privacy import PrivacyService
        return [dict(r) for r in self.db.execute('SELECT id,nickname,grade,age_band,instruction_language,avatar FROM children WHERE family_id=?', (auth['family_id'],)) if not PrivacyService(self).pending_deletion(auth['family_id'],r['id'])]

    def consents(self, auth):
        result = {p: False for p in ('learning', 'voice', 'photo', 'research')}
        for row in self.db.execute('SELECT purpose,granted FROM consent_events WHERE family_id=? ORDER BY rowid', (auth['family_id'],)):
            result[row['purpose']] = bool(row['granted'])
        return result

    def set_consent(self, auth, data):
        if data.get('purpose') not in ('learning', 'voice', 'photo', 'research') or type(data.get('granted')) is not bool or data.get('version') != 'engineering-v1':
            raise DomainError('VALIDATION_FAILED')
        with self.db:
            self.db.execute('INSERT INTO consent_events VALUES (?,?,?,?,?,?)',
                (uid(), auth['family_id'], data['purpose'], data['version'], int(data['granted']), now()))
            if data['purpose'] == 'learning' and not data['granted']:
                self.db.execute("UPDATE learning_sessions SET state='cancelled', revision=revision+1 WHERE child_id IN (SELECT id FROM children WHERE family_id=?) AND state NOT IN ('completed','cancelled')", (auth['family_id'],))
        return self.consents(auth)

    def require_consent(self, auth):
        if not self.consents(auth)['learning']:
            raise DomainError('CONSENT_REQUIRED', 403)

    def create_child(self, auth, data):
        self.require_consent(auth)
        nickname = data.get('nickname')
        if not isinstance(nickname, str) or not 1 <= len(nickname.strip()) <= 30 or type(data.get('grade')) is not int or data['grade'] not in range(1,5) or data.get('instruction_language') not in ('ru-KZ','kk-KZ') or data.get('age_band') not in ('6-7','8-9','10-11') or data.get('avatar') not in ('owl','fox','cat'):
            raise DomainError('VALIDATION_FAILED')
        with self.db:
            if self.db.execute('SELECT count(*) FROM children WHERE family_id=?', (auth['family_id'],)).fetchone()[0] >= self.tariff()['max_saved_profiles']:
                raise DomainError('PROFILE_LIMIT', 429)
            child_id = uid()
            self.db.execute('INSERT INTO children VALUES (?,?,?,?,?,?,?)', (child_id, auth['family_id'], nickname.strip(), data['grade'], data['age_band'], data['instruction_language'], data['avatar']))
        return next(c for c in self.children(auth) if c['id'] == child_id)

    def owned_child(self, auth, child_id):
        row = self.db.execute('SELECT * FROM children WHERE id=? AND family_id=?', (child_id, auth['family_id'])).fetchone()
        from backend.privacy import PrivacyService
        if PrivacyService(self).pending_deletion(auth['family_id'],child_id):raise DomainError('NOT_FOUND',404)
        if not row or (auth['child_id'] and auth['child_id'] != child_id):
            raise DomainError('NOT_FOUND', 404)
        return dict(row)

    def child_token(self, auth, child_id):
        self.require_consent(auth)
        self.owned_child(auth, child_id)
        with self.db:
            token = self.issue_token(auth['family_id'], child_id)
        return {'token': token}

    def curriculum(self, auth):
        if not auth['child_id']:
            raise DomainError('CHILD_AUTH_REQUIRED', 403)
        child = self.owned_child(auth, auth['child_id'])
        # Never silently substitute Russian grade-1 material for another track.
        available = child['grade'] == 1 and child['instruction_language'] == 'ru-KZ'
        from backend.content import ContentService
        published=ContentService(self).published(child['grade'],child['instruction_language'])
        return {'official_coverage': False, 'version': 'engineering-fixture-v1',
                'lessons': published+([LESSON] if available else []),
                'unavailable_reason': None if available or published else 'CURRICULUM_UNAVAILABLE'}

    def operation(self, scope, key, data):
        if not isinstance(key, str) or not 1 <= len(key) <= 120:
            raise DomainError('IDEMPOTENCY_KEY_REQUIRED')
        row = self.db.execute('SELECT * FROM operations WHERE scope=? AND operation_key=?', (scope,key)).fetchone()
        if row:
            if row['payload_hash'] != payload_hash(data):
                raise DomainError('IDEMPOTENCY_CONFLICT', 409)
            return json.loads(row['response'])

    def start(self, auth, data, key):
        self.require_consent(auth)
        if self.trial_status(auth)['status'] != 'active':
            raise DomainError('ACCESS_REQUIRED',403)
        if not auth['child_id']:
            raise DomainError('CHILD_AUTH_REQUIRED', 403)
        if data.get('lesson_id') not in [l['id'] for l in self.curriculum(auth)['lessons']]:
            raise DomainError('CURRICULUM_UNAVAILABLE', 422)
        scope = 'start:' + auth['child_id']
        with self.db:
            prior = self.operation(scope, key, data)
            if prior:
                return prior
            session_id = uid()
            self.db.execute('INSERT INTO learning_sessions VALUES (?,?,?,?,?,?,?,?,?)',
                (session_id, auth['child_id'], data['lesson_id'], 'awaiting_input', 1, 1, 0, 0, now()))
            result = self.session(auth, session_id)
            self.db.execute('INSERT INTO operations VALUES (?,?,?,?)', (scope,key,payload_hash(data),json.dumps(result)))
        return result

    def session(self, auth, session_id):
        row = self.db.execute('SELECT * FROM learning_sessions WHERE id=?', (session_id,)).fetchone()
        if not row:
            raise DomainError('NOT_FOUND', 404)
        self.owned_child(auth, row['child_id'])
        result = dict(row)
        result['question'] = '5 + 2 = ?' if row['step'] == 0 else '4 + 3 = ?'
        result['board'] = dict(LESSON['board'], groups=[5,2] if row['step'] == 0 else [4,3],
                               alt_text='Пять и ещё два' if row['step'] == 0 else 'Четыре и ещё три')
        result['step_id'] = 'step_' + str(row['step'])
        if row['lesson_id']!=LESSON_ID:
            from backend.content import ContentService
            lesson=ContentService(self).get(row['lesson_id'])
            data=lesson['payload'];step=data['steps'][row['step']]
            result.update(question=step['question'],choices=step['choices'],explanation=data['explanation'],hint=data['hint'],
                title=data['title'],locale=data['locale'],board={'schema_version':'1.0','type':'equation','expression':step['expression'],'alt_text':step['question']})
        return result

    def attempt(self, auth, session_id, data, revision):
        self.require_consent(auth)
        current = self.session(auth, session_id)
        if not auth['child_id']:
            raise DomainError('CHILD_AUTH_REQUIRED', 403)
        event = data.get('client_event_id')
        if not isinstance(event, str) or not 1 <= len(event) <= 120:
            raise DomainError('VALIDATION_FAILED')
        with self.db:
            prior = self.db.execute('SELECT * FROM attempts WHERE session_id=? AND client_event_id=?', (session_id,event)).fetchone()
            if prior:
                if prior['payload_hash'] != payload_hash(data):
                    raise DomainError('IDEMPOTENCY_CONFLICT', 409)
                return json.loads(prior['response'])
            if revision != current['revision'] or data.get('task_revision') != current['task_revision'] or data.get('step_id') != current['step_id']:
                raise DomainError('REVISION_CONFLICT', 409)
            if current['state'] != 'awaiting_input':
                raise DomainError('SESSION_STATE_CONFLICT', 409)
            value = data.get('input', {}).get('value') if isinstance(data.get('input'), dict) else None
            expected=7;max_answer=20
            if current['lesson_id']!=LESSON_ID:
                from backend.content import ContentService
                lesson=ContentService(self).get(current['lesson_id'])
                if lesson['status']!='published':raise DomainError('CONTENT_REVOKED',403)
                expected=lesson['payload']['steps'][current['step']]['answer'];max_answer=1000000
            if type(value) is not int or not 0 <= value <= max_answer:
                evaluation, feedback = 'needs_clarification', 'Выбери число от 0 до 20. Это не считается ошибкой.'
            elif value != expected:
                evaluation, feedback = 'incorrect', 'Посчитай кружки по одному. Начни с первой группы и добавь вторую.'
                self.db.execute('UPDATE learning_sessions SET help_level=help_level+1 WHERE id=?', (session_id,))
            else:
                evaluation = 'correct'
                feedback = 'Получилось! Теперь попробуй похожее задание самостоятельно.' if current['step'] == 0 else 'Ты самостоятельно решил похожее задание. Занятие завершено.'
                self.db.execute('UPDATE learning_sessions SET step=1,task_revision=task_revision+1,state=? WHERE id=?', ('awaiting_input' if current['step'] == 0 else 'completed',session_id))
            if current['lesson_id']!=LESSON_ID:
                kk=current.get('locale')=='kk-KZ'
                if evaluation=='incorrect':feedback=current['hint']
                elif evaluation=='needs_clarification':feedback='Жауап нұсқасын таңда. Бұл қате болып саналмайды.' if kk else 'Выбери вариант ответа. Это не считается ошибкой.'
                elif kk:feedback='Жарайсың! Енді ұқсас тапсырманы өз бетіңше орында.' if current['step']==0 else 'Ұқсас тапсырманы өз бетіңше орындадың. Сабақ аяқталды.'
            self.db.execute('UPDATE learning_sessions SET revision=revision+1 WHERE id=?', (session_id,))
            result = {'accepted_event_id': event, 'evaluation': evaluation, 'feedback': feedback,
                      'session': self.session(auth, session_id)}
            self.db.execute('INSERT INTO learning_evidence VALUES (?,?,?,?,?)',(uid(),session_id,current['step'],evaluation,now()))
            self.db.execute('INSERT INTO attempts VALUES (?,?,?,?,?,?,?)',
                (uid(),session_id,event,payload_hash(data),json.dumps(result),evaluation,now()))
        return result

    def hint(self,auth,session_id,revision,key):
        self.require_consent(auth)
        if not auth['child_id']:raise DomainError('CHILD_AUTH_REQUIRED',403)
        current=self.session(auth,session_id)
        with self.db:
            prior=self.operation('hint:'+session_id,key,{})
            if prior:return prior
            if current['state']!='awaiting_input':raise DomainError('SESSION_STATE_CONFLICT',409)
            if revision!=current['revision']:raise DomainError('REVISION_CONFLICT',409)
            text=current.get('hint','Посчитай кружки первой группы. Затем добавь кружки второй группы.')
            self.db.execute('INSERT INTO learning_evidence VALUES (?,?,?,?,?)',(uid(),session_id,current['step'],'hint',now()))
            self.db.execute('UPDATE learning_sessions SET help_level=help_level+1,revision=revision+1 WHERE id=?',(session_id,))
            result={'hint':text,'session':self.session(auth,session_id)}
            self.db.execute('INSERT INTO operations VALUES (?,?,?,?)',('hint:'+session_id,key,payload_hash({}),json.dumps(result)))
        return result

    def transition(self, auth, session_id, action, revision):
        self.require_consent(auth)
        current = self.session(auth, session_id)
        if not auth['child_id']:
            raise DomainError('CHILD_AUTH_REQUIRED', 403)
        if current['revision'] != revision:
            raise DomainError('REVISION_CONFLICT',409)
        if current['state'] not in ('awaiting_input','paused'):
            raise DomainError('SESSION_STATE_CONFLICT',409)
        state = {'pause':'paused','resume':'awaiting_input','cancel':'cancelled'}.get(action)
        if not state or (action == 'resume' and current['state'] != 'paused'):
            raise DomainError('SESSION_STATE_CONFLICT',409)
        with self.db:
            self.db.execute('UPDATE learning_sessions SET state=?,revision=revision+1 WHERE id=?', (state,session_id))
        return self.session(auth,session_id)

    def progress(self, auth, child_id):
        self.owned_child(auth,child_id)
        completed=self.db.execute("SELECT count(*) FROM learning_sessions WHERE child_id=? AND state='completed'",(child_id,)).fetchone()[0]
        topics={}
        for session in self.db.execute("SELECT * FROM learning_sessions WHERE child_id=? AND state='completed' ORDER BY rowid",(child_id,)):
            if session['lesson_id']==LESSON_ID:
                objective,version,title='engineering-add-to-10','engineering-fixture-v1',LESSON['title']
            else:
                from backend.content import ContentService
                lesson=ContentService(self).get(session['lesson_id'])
                objective,version,title=lesson['objective_id'],lesson['payload']['academic_year'],lesson['payload']['title']
            key=objective+':'+version
            topic=topics.setdefault(key,{'objective_id':objective,'curriculum_version':version,'title':title,'completed_sessions':0,'independent_transfer':0,'assisted_transfer':0,'uncertain_sessions':0,'hints':0,'status':'needs_more_evidence'})
            evidence=list(self.db.execute('SELECT step,kind FROM learning_evidence WHERE session_id=?',(session['id'],)))
            transfer=[e for e in evidence if e['step']==1]
            topic['completed_sessions']+=1
            topic['hints']+=sum(e['kind']=='hint' for e in evidence)
            if not any(e['kind']=='correct' for e in transfer):topic['uncertain_sessions']+=1
            elif any(e['kind'] in ('hint','incorrect') for e in transfer):topic['assisted_transfer']+=1
            else:topic['independent_transfer']+=1
            if topic['assisted_transfer']:topic['status']='practice_with_support'
        return {'child_id':child_id,'completed_sessions':completed,'curriculum_version':'per_objective',
                'official_assessment':False,'mastery_claimed':False,'topics':list(topics.values()),
                'description':'Самостоятельный перенос и помощь учитываются отдельно. Это не школьная оценка; повтор одного примера не доказывает освоение цели.'}

    def is_admin(self, family_id):
        return bool(self.db.execute('SELECT 1 FROM administrator_roles WHERE family_id=?',(family_id,)).fetchone())

    def require_admin(self, auth):
        if auth['child_id'] or not self.is_admin(auth['family_id']):
            raise DomainError('ADMIN_AUTH_REQUIRED',403)

    def tariff(self):
        result=dict(self.db.execute('SELECT name,price_per_child_kzt,max_saved_profiles,revision,updated_at FROM tariff_configuration WHERE id=1').fetchone())
        result['trial_days']=self.db.execute('SELECT duration_days FROM trial_policy WHERE id=1').fetchone()[0]
        return result

    def update_tariff(self, auth, data, revision):
        self.require_admin(auth)
        name, price, profiles = (data.get(k) for k in ('name','price_per_child_kzt','max_saved_profiles'))
        days=data.get('trial_days',self.tariff()['trial_days'])
        if not isinstance(name,str) or not 1<=len(name.strip())<=80 or type(price) is not int or not 1<=price<=1000000 or type(profiles) is not int or not 1<=profiles<=5 or type(days) is not int or not 1<=days<=30:
            raise DomainError('VALIDATION_FAILED')
        with self.db:
            old=self.tariff()
            if old['revision'] != revision:
                raise DomainError('REVISION_CONFLICT',409)
            cursor=self.db.execute('UPDATE tariff_configuration SET name=?,price_per_child_kzt=?,max_saved_profiles=?,revision=revision+1,updated_at=? WHERE id=1 AND revision=?',
                (name.strip(),price,profiles,now(),revision))
            if cursor.rowcount != 1:
                raise DomainError('REVISION_CONFLICT',409)
            self.db.execute('UPDATE trial_policy SET duration_days=? WHERE id=1',(days,))
            new=self.tariff()
            self.db.execute('INSERT INTO tariff_audit VALUES (?,?,?,?,?)',
                (uid(),auth['family_id'],json.dumps(old),json.dumps(new),now()))
        return new

    def quote(self, auth, data):
        ids=data.get('child_ids')
        if not isinstance(ids,list) or not ids or len(ids)>5 or any(not isinstance(c,str) for c in ids) or len(ids)!=len(set(ids)):
            raise DomainError('VALIDATION_FAILED')
        children=[self.owned_child(auth,c) for c in ids]
        config=self.tariff()
        price=config['price_per_child_kzt']
        return {'tariff_name':config['name'],'tariff_revision':config['revision'],
                'currency':'KZT','period':'month','quantity':len(ids),
                'items':[{'child_id':c['id'],'nickname':c['nickname'],'grade':c['grade'],'unit_amount':price} for c in children],
                'total_amount':price*len(ids),'price_configured':True,'purchasable':False,
                'reason':'STORE_VERIFICATION_NOT_CONFIGURED'}

    def trial_status(self, auth):
        row=self.db.execute('SELECT * FROM family_trials WHERE family_id=?',(auth['family_id'],)).fetchone()
        if not row:
            return {'status':'eligible','duration_days':self.tariff()['trial_days'],
                    'once_per_family':True,'all_family_profiles':True,'auto_renew':False,
                    'requires_payment_card':False,'remaining_seconds':0}
        remaining=max(0,int(row['expires_at']-time.time()))
        return {'status':'active' if row['expires_at']>time.time() else 'expired',
                'duration_days':row['duration_days'],'once_per_family':True,
                'all_family_profiles':True,'auto_renew':False,'requires_payment_card':False,
                'remaining_seconds':remaining,
                'started_at':datetime.fromtimestamp(row['started_at'],timezone.utc).isoformat(),
                'expires_at':datetime.fromtimestamp(row['expires_at'],timezone.utc).isoformat()}

    def activate_trial(self, auth, key):
        if auth['child_id']:
            raise DomainError('PARENT_AUTH_REQUIRED',403)
        self.require_consent(auth)
        with self.db:
            # Acquire write lock before checking eligibility; two devices cannot restart a trial.
            self.db.execute('BEGIN IMMEDIATE')
            prior=self.operation('trial:'+auth['family_id'],key,{})
            if prior:
                return self.trial_status(auth)
            if self.db.execute('SELECT 1 FROM family_trials WHERE family_id=?',(auth['family_id'],)).fetchone():
                raise DomainError('TRIAL_ALREADY_USED',409)
            config=self.tariff()
            started=time.time()
            self.db.execute('INSERT INTO family_trials VALUES (?,?,?,?,?)',
                (auth['family_id'],started,started+config['trial_days']*86400,config['trial_days'],config['revision']))
            result=self.trial_status(auth)
            self.db.execute('INSERT INTO operations VALUES (?,?,?,?)',
                ('trial:'+auth['family_id'],key,payload_hash({}),json.dumps(result)))
        return result
