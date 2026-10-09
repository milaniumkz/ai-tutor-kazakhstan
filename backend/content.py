"""Versioned original lessons. Publication requires independent human reviews."""
import hashlib
import json
import re
from pathlib import Path
from backend.domain import DomainError,uid,now

ROOT=Path(__file__).resolve().parents[1]

def canonical(value):
    return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))

def evaluate(expression):
    if not isinstance(expression,dict) or set(expression)!={'op','left','right'}:
        raise DomainError('CONTENT_SCHEMA_INVALID')
    a,b=expression['left'],expression['right']
    if type(a) is not int or type(b) is not int or not 0<=a<=1000000 or not 0<=b<=1000000:
        raise DomainError('CONTENT_SCHEMA_INVALID')
    op=expression['op']
    if op=='add':result=a+b
    elif op=='subtract':result=a-b
    elif op=='multiply':result=a*b
    elif op=='divide' and b and a%b==0:result=a//b
    else:raise DomainError('CONTENT_SCHEMA_INVALID')
    if not 0<=result<=1000000:raise DomainError('CONTENT_SCHEMA_INVALID')
    return result

def validate_lesson(data):
    required=('title','locale','objective_id','academic_year','term','explanation','hint','steps','rights')
    if not isinstance(data,dict) or any(k not in data for k in required):raise DomainError('CONTENT_SCHEMA_INVALID')
    if data['locale'] not in ('ru-KZ','kk-KZ') or not isinstance(data['academic_year'],str) or not re.fullmatch(r'20\d{2}-20\d{2}',data['academic_year']):raise DomainError('CONTENT_SCHEMA_INVALID')
    if type(data['term']) is not int or data['term'] not in range(1,5):raise DomainError('CONTENT_SCHEMA_INVALID')
    for key,limit in [('title',100),('explanation',2000),('hint',700)]:
        if not isinstance(data[key],str) or not 1<=len(data[key].strip())<=limit:raise DomainError('CONTENT_SCHEMA_INVALID')
    if not isinstance(data['rights'],dict) or data['rights'].get('kind')!='original' or not isinstance(data['rights'].get('evidence'),str) or len(data['rights']['evidence'])<10:raise DomainError('RIGHTS_REQUIRED')
    if not isinstance(data['steps'],list) or len(data['steps'])!=2:raise DomainError('CONTENT_SCHEMA_INVALID')
    for step in data['steps']:
        if not isinstance(step,dict) or not isinstance(step.get('question'),str) or not 1<=len(step['question'])<=300:raise DomainError('CONTENT_SCHEMA_INVALID')
        correct=evaluate(step.get('expression'))
        expression=step['expression']
        symbol={'add':'+','subtract':'−','multiply':'×','divide':'÷'}[expression['op']]
        expected=f"{expression['left']} {symbol} {expression['right']} = ?"
        if step['question'] != expected:raise DomainError('QUESTION_EXPRESSION_MISMATCH')
        if type(step.get('answer')) is not int or step['answer']!=correct:raise DomainError('REFERENCE_ANSWER_INVALID')
        choices=step.get('choices')
        if not isinstance(choices,list) or len(choices)!=3 or any(type(n) is not int for n in choices) or len(set(choices))!=3 or correct not in choices:raise DomainError('CONTENT_SCHEMA_INVALID')
    if data['steps'][0]['expression']==data['steps'][1]['expression']:raise DomainError('TRANSFER_TASK_REQUIRED')
    return data

class ContentService:
    def __init__(self,repo):
        self.repo=repo;self.db=repo.db

    def roles(self,auth):
        result={row[0] for row in self.db.execute('SELECT role FROM content_roles WHERE account_id=?',(auth['family_id'],))}
        if self.repo.is_admin(auth['family_id']):result.update(('editor','publisher'))
        return result

    def require(self,auth,roles):
        if auth['child_id'] or not self.roles(auth).intersection(roles):raise DomainError('CONTENT_ROLE_REQUIRED',403)

    def seed(self):
        source_path=ROOT/'content/curriculum-399.json'
        if not source_path.exists() or self.db.execute('SELECT count(*) FROM curriculum_sources').fetchone()[0]:return
        catalog=json.loads(source_path.read_text())
        with self.db:
            self.db.execute('INSERT INTO curriculum_sources VALUES (?,?)',(catalog['source']['id'],canonical(catalog['source'])))
            for objective in catalog['objectives']:
                subject=next(s for s in catalog['subjects'] if s['id']==objective['subject_id'])
                metadata=dict(objective,subject_title=subject['title'],source=catalog['source'])
                self.db.execute('INSERT INTO curriculum_objectives VALUES (?,?,?,?,?)',(objective['id'],objective['subject_id'],objective['code'],objective['grade'],canonical(metadata)))
            pack=ROOT/'content/original-math-lessons.json'
            if pack.exists():
                for lesson in json.loads(pack.read_text())['lessons']:
                    validate_lesson(lesson)
                    objective=self.db.execute('SELECT grade FROM curriculum_objectives WHERE id=?',(lesson['objective_id'],)).fetchone()
                    if not objective:raise DomainError('OBJECTIVE_NOT_FOUND')
                    encoded=canonical(lesson)
                    self.db.execute('INSERT INTO lesson_versions VALUES (?,?,?,?,?,?,?,?,?,?,?)',
                        (lesson['id'],lesson['id'],1,'prepared-original-content',lesson['objective_id'],objective[0],lesson['locale'],'draft',encoded,hashlib.sha256(encoded.encode()).hexdigest(),now()))

    def curriculum(self,auth,grade=None):
        self.require(auth,{'editor','method_reviewer','language_reviewer','publisher'})
        rows=self.db.execute('SELECT metadata FROM curriculum_objectives'+(' WHERE grade=?' if grade else '')+' ORDER BY subject_id,code', (grade,) if grade else ())
        return {'source_verified_download':True,'applicability_reviewed':False,'objectives':[json.loads(row[0]) for row in rows]}

    def list(self,auth):
        self.require(auth,{'editor','method_reviewer','language_reviewer','publisher'})
        return [self.get(row[0]) for row in self.db.execute('SELECT id FROM lesson_versions ORDER BY grade,locale,created_at')]

    def get(self,lesson_id):
        row=self.db.execute('SELECT * FROM lesson_versions WHERE id=?',(lesson_id,)).fetchone()
        if not row:raise DomainError('NOT_FOUND',404)
        result=dict(row);result['payload']=json.loads(result['payload']);return result

    def audit(self,auth,action,target):
        self.db.execute('INSERT INTO content_audit VALUES (?,?,?,?,?)',(uid(),auth['family_id'],action,target,now()))

    def create(self,auth,data):
        self.require(auth,{'editor'})
        validate_lesson(data)
        objective=self.db.execute('SELECT grade FROM curriculum_objectives WHERE id=?',(data['objective_id'],)).fetchone()
        if not objective:raise DomainError('OBJECTIVE_NOT_FOUND',422)
        if 'previous_version_id' in data:
            previous=self.get(data['previous_version_id']);logical=previous['logical_id']
        else:logical=uid()
        version=self.db.execute('SELECT coalesce(max(version),0)+1 FROM lesson_versions WHERE logical_id=?',(logical,)).fetchone()[0]
        lesson_id=uid();encoded=canonical(data)
        with self.db:
            self.db.execute('INSERT INTO lesson_versions VALUES (?,?,?,?,?,?,?,?,?,?,?)',(lesson_id,logical,version,auth['family_id'],data['objective_id'],objective[0],data['locale'],'draft',encoded,hashlib.sha256(encoded.encode()).hexdigest(),now()))
            self.audit(auth,'draft_created',lesson_id)
        return self.get(lesson_id)

    def submit(self,auth,lesson_id):
        self.require(auth,{'editor'})
        lesson=self.get(lesson_id)
        if lesson['author_id'] not in (auth['family_id'],'prepared-original-content'):raise DomainError('CONTENT_OWNERSHIP_REQUIRED',403)
        if lesson['status']!='draft':raise DomainError('CONTENT_STATE_CONFLICT',409)
        validate_lesson(lesson['payload'])
        with self.db:
            self.db.execute("UPDATE lesson_versions SET status='in_method_review' WHERE id=? AND status='draft'",(lesson_id,))
            self.audit(auth,'review_requested',lesson_id)
        return self.get(lesson_id)

    def review(self,auth,lesson_id,data):
        lesson=self.get(lesson_id)
        stage={'in_method_review':'method_reviewer','in_language_review':'language_reviewer'}.get(lesson['status'])
        if not stage:raise DomainError('CONTENT_STATE_CONFLICT',409)
        self.require(auth,{stage})
        if lesson['author_id']==auth['family_id']:raise DomainError('INDEPENDENT_REVIEW_REQUIRED',403)
        if data.get('decision') not in ('approve','reject') or not isinstance(data.get('notes'),str) or not 10<=len(data['notes'])<=1000:raise DomainError('VALIDATION_FAILED')
        if stage=='method_reviewer' and data['decision']=='approve' and data.get('normative_applicability_checked') is not True:raise DomainError('NORMATIVE_REVIEW_REQUIRED',422)
        state='draft' if data['decision']=='reject' else ('in_language_review' if stage=='method_reviewer' else 'approved')
        with self.db:
            self.db.execute('INSERT OR REPLACE INTO content_reviews VALUES (?,?,?,?,?,?,?)',(uid(),lesson_id,auth['family_id'],stage,data['decision'],data['notes'],now()))
            self.db.execute('UPDATE lesson_versions SET status=? WHERE id=?',(state,lesson_id))
            self.audit(auth,'review_'+data['decision'],lesson_id)
        return self.get(lesson_id)

    def publish(self,auth,lesson_id):
        self.require(auth,{'publisher'})
        lesson=self.get(lesson_id)
        if lesson['status']!='approved':raise DomainError('CONTENT_REVIEW_REQUIRED',409)
        if lesson['author_id']==auth['family_id']:raise DomainError('INDEPENDENT_PUBLISHER_REQUIRED',403)
        reviews=list(self.db.execute("SELECT stage,reviewer_id FROM content_reviews WHERE lesson_id=? AND decision='approve'",(lesson_id,)))
        if {r['stage'] for r in reviews}!={'method_reviewer','language_reviewer'} or any(r['reviewer_id']==lesson['author_id'] for r in reviews):raise DomainError('INDEPENDENT_REVIEW_REQUIRED',403)
        validate_lesson(lesson['payload'])
        manifest={'schema_version':'1.0','lesson_id':lesson_id,'sha256':lesson['payload_hash'],'version':lesson['version'],'published_at':now()}
        with self.db:
            self.db.execute('INSERT INTO content_releases VALUES (?,?,?,?,?)',(uid(),lesson_id,canonical(manifest),auth['family_id'],now()))
            previous=[r[0] for r in self.db.execute("SELECT id FROM lesson_versions WHERE logical_id=? AND status='published'",(lesson['logical_id'],))]
            for target in previous:self.db.execute("UPDATE learning_sessions SET state='cancelled',revision=revision+1 WHERE lesson_id=? AND state NOT IN ('completed','cancelled')",(target,))
            self.db.execute("UPDATE lesson_versions SET status='retired' WHERE logical_id=? AND status='published'",(lesson['logical_id'],))
            self.db.execute("UPDATE lesson_versions SET status='published' WHERE id=?",(lesson_id,))
            self.audit(auth,'published',lesson_id)
        return manifest

    def rollback(self,auth,lesson_id):
        self.require(auth,{'publisher'})
        lesson=self.get(lesson_id)
        if lesson['author_id']==auth['family_id']:raise DomainError('INDEPENDENT_PUBLISHER_REQUIRED',403)
        release=self.db.execute('SELECT manifest FROM content_releases WHERE lesson_id=? ORDER BY rowid DESC LIMIT 1',(lesson_id,)).fetchone()
        if lesson['status']!='retired' or not release:raise DomainError('CONTENT_ROLLBACK_UNAVAILABLE',409)
        manifest=json.loads(release[0])
        if manifest['sha256']!=lesson['payload_hash']:raise DomainError('CONTENT_INTEGRITY_FAILED',409)
        validate_lesson(lesson['payload'])
        with self.db:
            for row in self.db.execute("SELECT id FROM lesson_versions WHERE logical_id=? AND status='published'",(lesson['logical_id'],)):
                self.db.execute("UPDATE learning_sessions SET state='cancelled',revision=revision+1 WHERE lesson_id=? AND state NOT IN ('completed','cancelled')",(row[0],))
            self.db.execute("UPDATE lesson_versions SET status='retired' WHERE logical_id=? AND status='published'",(lesson['logical_id'],))
            self.db.execute("UPDATE lesson_versions SET status='published' WHERE id=?",(lesson_id,))
            self.db.execute('INSERT INTO content_releases VALUES (?,?,?,?,?)',(uid(),lesson_id,canonical(dict(manifest,rollback=True,published_at=now())),auth['family_id'],now()))
            self.audit(auth,'rollback',lesson_id)
        return self.public(lesson_id)

    def retire(self,auth,lesson_id):
        self.require(auth,{'publisher'})
        lesson=self.get(lesson_id)
        if lesson['status']!='published':raise DomainError('CONTENT_STATE_CONFLICT',409)
        with self.db:
            self.db.execute("UPDATE lesson_versions SET status='retired' WHERE id=?",(lesson_id,))
            self.db.execute("UPDATE learning_sessions SET state='cancelled',revision=revision+1 WHERE lesson_id=? AND state NOT IN ('completed','cancelled')",(lesson_id,))
            self.audit(auth,'retired',lesson_id)
        return {'retired':True}

    def published(self,grade,locale):
        return [self.public(row[0]) for row in self.db.execute("SELECT id FROM lesson_versions WHERE status='published' AND grade=? AND locale=?",(grade,locale))]

    def public(self,lesson_id):
        lesson=self.get(lesson_id);data=lesson['payload']
        return {'id':lesson_id,'title':data['title'],'grade':lesson['grade'],'locale':lesson['locale'],
            'objective_id':lesson['objective_id'],'curriculum_version_id':data['academic_year'],
            'subject':'mathematics','status':lesson['status'],'official_curriculum':False,
            'question':data['steps'][0]['question'],'source':'Авторский урок, нормативная цель '+lesson['objective_id'],
            'version':lesson['version']}
