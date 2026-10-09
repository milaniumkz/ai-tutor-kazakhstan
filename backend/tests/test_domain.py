import tempfile
import unittest
from pathlib import Path
from backend.domain import Repository, DomainError, LESSON_ID

class DomainTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name)/'db.sqlite'
        self.repo = Repository(self.path)
        self.credentials = {'login':'adult-test','password':'test-password-123','pin':'123456'}
        result = self.repo.register(self.credentials)
        self.token = result['token']
        self.parent = self.repo.authenticate(self.token,'123456',True)
        self.repo.set_consent(self.parent,{'purpose':'learning','granted':True,'version':'engineering-v1'})
        self.repo.activate_trial(self.parent,'setup-trial')
        self.child = self.repo.create_child(self.parent,{'nickname':'Сова','grade':1,'age_band':'6-7','instruction_language':'ru-KZ','avatar':'owl'})
        token = self.repo.child_token(self.parent,self.child['id'])['token']
        self.auth = self.repo.authenticate(token)

    def tearDown(self):
        self.repo.close()
        self.tmp.cleanup()

    def session(self):
        return self.repo.start(self.auth,{'lesson_id':LESSON_ID},'start-key')

    def attempt(self,session,value,event='event-1'):
        data = {'client_event_id':event,'task_revision':session['task_revision'],
                'step_id':session['step_id'],'input':{'type':'choice','value':value}}
        return self.repo.attempt(self.auth,session['id'],data,session['revision']),data

    def test_login_and_persistence(self):
        self.repo.close()
        self.repo = Repository(self.path)
        token = self.repo.login(self.credentials)['token']
        auth = self.repo.authenticate(token,'123456',True)
        self.assertEqual(self.repo.children(auth)[0]['nickname'],'Сова')

    def test_no_plaintext_password_or_token(self):
        row = self.repo.db.execute('SELECT * FROM families').fetchone()
        self.assertNotEqual(row['password_hash'],self.credentials['password'])
        self.assertNotEqual(row['pin_hash'],'123456')
        self.assertIsNone(self.repo.db.execute('SELECT * FROM auth_sessions WHERE token_hash=?',(self.token,)).fetchone())

    def test_pin_required(self):
        with self.assertRaises(DomainError) as error:
            self.repo.authenticate(self.token,'999999',True)
        self.assertEqual(error.exception.code,'PARENT_AUTH_REQUIRED')

    def test_pin_rate_limit(self):
        for _ in range(5):
            with self.assertRaises(DomainError):self.repo.authenticate(self.token,'999999',True)
        with self.assertRaises(DomainError) as error:self.repo.authenticate(self.token,'123456',True)
        self.assertEqual(error.exception.status,429)

    def test_child_token_cannot_open_parent_scope(self):
        token = self.repo.child_token(self.parent,self.child['id'])['token']
        with self.assertRaises(DomainError):self.repo.authenticate(token,'123456',True)

    def test_family_isolation(self):
        other = self.repo.register({'login':'other-family','password':'other-password','pin':'987654'})
        auth = self.repo.authenticate(other['token'],'987654',True)
        with self.assertRaises(DomainError) as error:self.repo.owned_child(auth,self.child['id'])
        self.assertEqual(error.exception.status,404)
        session = self.session()
        with self.assertRaises(DomainError):self.repo.session(auth,session['id'])

    def test_sibling_isolation(self):
        other = self.repo.create_child(self.parent,{'nickname':'Лиса','grade':1,'age_band':'6-7','instruction_language':'ru-KZ','avatar':'fox'})
        with self.assertRaises(DomainError):self.repo.progress(self.auth,other['id'])

    def test_optional_consents_not_preselected(self):
        self.assertEqual(self.repo.consents(self.parent),{'learning':True,'voice':False,'photo':False,'research':False})

    def test_revoke_stops_session(self):
        session = self.session()
        self.repo.set_consent(self.parent,{'purpose':'learning','granted':False,'version':'engineering-v1'})
        self.assertEqual(self.repo.session(self.auth,session['id'])['state'],'cancelled')
        with self.assertRaises(DomainError):self.attempt(session,7)

    def test_no_silent_curriculum_substitution(self):
        self.repo.db.execute('UPDATE children SET grade=3 WHERE id=?',(self.child['id'],))
        self.assertEqual(self.repo.curriculum(self.auth)['lessons'],[])
        with self.assertRaises(DomainError):self.session()

    def test_unsupported_language(self):
        self.repo.db.execute("UPDATE children SET instruction_language='kk-KZ' WHERE id=?",(self.child['id'],))
        self.assertEqual(self.repo.curriculum(self.auth)['lessons'],[])

    def test_session_idempotency(self):
        self.assertEqual(self.session()['id'],self.session()['id'])
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM learning_sessions').fetchone()[0],1)

    def test_complete_requires_independent_transfer(self):
        session = self.session()
        result,_ = self.attempt(session,7)
        self.assertEqual(result['session']['state'],'awaiting_input')
        self.assertEqual(self.repo.progress(self.auth,self.child['id'])['completed_sessions'],0)
        result,_ = self.attempt(result['session'],7,'transfer')
        self.assertEqual(result['session']['state'],'completed')
        self.assertEqual(self.repo.progress(self.auth,self.child['id'])['completed_sessions'],1)

    def test_duplicate_attempt_returns_same_result(self):
        session = self.session()
        result,data = self.attempt(session,7)
        self.assertEqual(result,self.repo.attempt(self.auth,session['id'],data,1))
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM attempts').fetchone()[0],1)

    def test_duplicate_event_changed_payload_rejected(self):
        session = self.session()
        _,data = self.attempt(session,7)
        data['input']['value']=8
        with self.assertRaises(DomainError) as error:self.repo.attempt(self.auth,session['id'],data,1)
        self.assertEqual(error.exception.code,'IDEMPOTENCY_CONFLICT')

    def test_stale_revision_rejected(self):
        session = self.session()
        self.attempt(session,6)
        with self.assertRaises(DomainError) as error:self.attempt(session,7,'stale')
        self.assertEqual(error.exception.code,'REVISION_CONFLICT')

    def test_unclear_input_not_an_error(self):
        result,_ = self.attempt(self.session(),True)
        self.assertEqual(result['evaluation'],'needs_clarification')
        self.assertEqual(result['session']['help_level'],0)

    def test_pause_resume_cancel(self):
        session = self.session()
        paused = self.repo.transition(self.auth,session['id'],'pause',1)
        with self.assertRaises(DomainError):self.attempt(paused,7)
        resumed = self.repo.transition(self.auth,session['id'],'resume',2)
        cancelled = self.repo.transition(self.auth,session['id'],'cancel',resumed['revision'])
        self.assertEqual(cancelled['state'],'cancelled')

    def test_profiles_limit_and_validation(self):
        for n in range(4):self.repo.create_child(self.parent,{'nickname':str(n),'grade':n+1,'age_band':'8-9','instruction_language':'ru-KZ','avatar':'cat'})
        with self.assertRaises(DomainError) as error:self.repo.create_child(self.parent,{'nickname':'sixth','grade':1,'age_band':'6-7','instruction_language':'ru-KZ','avatar':'owl'})
        self.assertEqual(error.exception.code,'PROFILE_LIMIT')

    def test_progress_survives_restart(self):
        result,_ = self.attempt(self.session(),7)
        self.attempt(result['session'],7,'transfer')
        self.repo.close()
        self.repo = Repository(self.path)
        self.assertEqual(self.repo.progress(self.auth,self.child['id'])['completed_sessions'],1)



    def test_hint_is_server_recorded_idempotent_and_transfer_support_is_separate(self):
        first=self.session()
        hinted=self.repo.hint(self.auth,first['id'],first['revision'],'hint-first')
        self.assertEqual(hinted,self.repo.hint(self.auth,first['id'],first['revision'],'hint-first'))
        transfer,_=self.attempt(hinted['session'],7,'first-correct')
        final,_=self.attempt(transfer['session'],7,'transfer-correct')
        topic=self.repo.progress(self.parent,self.child['id'])['topics'][0]
        self.assertEqual(topic['hints'],1)
        self.assertEqual(topic['independent_transfer'],1)
        self.assertEqual(topic['assisted_transfer'],0)
        self.assertFalse(self.repo.progress(self.parent,self.child['id'])['mastery_claimed'])
    def test_incomplete_session_is_not_evidence_of_mastery(self):
        session=self.session();self.attempt(session,7,'first-only')
        self.assertEqual(self.repo.progress(self.parent,self.child['id'])['topics'],[])
    def test_hint_on_transfer_is_assistance(self):
        first=self.session();transfer,_=self.attempt(first,7,'first-correct')
        hinted=self.repo.hint(self.auth,first['id'],transfer['session']['revision'],'hint-transfer')
        self.attempt(hinted['session'],7,'last-correct')
        topic=self.repo.progress(self.parent,self.child['id'])['topics'][0]
        self.assertEqual(topic['independent_transfer'],0)
        self.assertEqual(topic['assisted_transfer'],1)
