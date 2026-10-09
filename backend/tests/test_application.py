import json
import os
import tempfile
import threading
import unittest
from http.server import HTTPServer
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from backend.application import Handler
from backend.domain import Repository

class ApplicationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.database = str(Path(self.tmp.name)/'app.sqlite')
        repo = Repository(self.database)
        account = repo.register({'login':'billing-test','password':'test-password-long','pin':'123456'})
        self.token = account['token']
        parent = repo.authenticate(self.token,'123456',True)
        repo.set_consent(parent,{'purpose':'learning','version':'engineering-v1','granted':True})
        repo.activate_trial(parent,'setup-trial')
        self.children = [repo.create_child(parent,{'nickname':'Профиль '+str(grade),'grade':grade,
            'age_band':'8-9','instruction_language':'ru-KZ','avatar':'owl'}) for grade in (1,3,4)]
        self.child_token = repo.child_token(parent,self.children[0]['id'])['token']
        other = repo.register({'login':'other-family','password':'test-password-long','pin':'987654'})
        self.other_token = other['token']
        repo.close()
        self.server = HTTPServer(('127.0.0.1',0),Handler)
        self.server.database_path = self.database
        self.thread = threading.Thread(target=self.server.serve_forever,daemon=True)
        self.thread.start()
        self.base = 'http://127.0.0.1:'+str(self.server.server_port)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.tmp.cleanup()

    def request(self,path,data=None,token=None,pin='123456',extra=None):
        headers = {'Content-Type':'application/json','Authorization':'Bearer '+(token or self.token)}
        if pin is not None:headers['X-Parent-Pin']=pin
        headers.update(extra or {})
        req = Request(self.base+path,data=None if data is None else json.dumps(data).encode(),headers=headers)
        try:response=urlopen(req,timeout=5)
        except HTTPError as error:response=error
        with response:return response.status,json.load(response)

    def test_per_child_price_across_grades(self):
        with patch.dict(os.environ,{'IGNORED_TEST_CONTEXT':'1'}):
            status,result=self.request('/v1/billing/quote',{'child_ids':[c['id'] for c in self.children]})
            self.assertEqual(status,200)
            self.assertEqual(result['quantity'],3)
            self.assertEqual(result['total_amount'],30000)
            self.assertEqual([i['grade'] for i in result['items']],[1,3,4])
            self.assertFalse(result['purchasable'])
            status,result=self.request('/v1/billing/quote',{'child_ids':[self.children[1]['id']]})
            self.assertEqual(result['total_amount'],10000)

    def test_approved_price_is_configured(self):
        with patch.dict(os.environ,{'TUTOR_PRICE_PER_CHILD_KZT':''}):
            status,result=self.request('/v1/billing/quote',{'child_ids':[self.children[0]['id']]})
            self.assertEqual(status,200)
            self.assertEqual(result['total_amount'],10000)
            self.assertTrue(result['price_configured'])

    def test_duplicate_or_empty_billable_profiles_rejected(self):
        child_id=self.children[0]['id']
        for ids in ([],[child_id,child_id]):
            status,result=self.request('/v1/billing/quote',{'child_ids':ids})
            self.assertEqual(status,400)

    def test_foreign_family_not_billable(self):
        status,result=self.request('/v1/billing/quote',{'child_ids':[self.children[0]['id']]},self.other_token,'987654')
        self.assertEqual(status,404)

    def test_child_cannot_quote_or_list_family(self):
        status,result=self.request('/v1/billing/quote',{'child_ids':[self.children[0]['id']]},self.child_token)
        self.assertEqual(status,403)
        status,result=self.request('/v1/children',token=self.child_token)
        self.assertEqual(status,403)

    def test_parent_pin_required_on_parent_endpoints(self):
        status,result=self.request('/v1/children',pin=None)
        self.assertEqual(status,403)

    def test_logout_revokes_family_tokens(self):
        status,result=self.request('/v1/auth/logout',{},pin=None)
        self.assertEqual(status,200)
        status,result=self.request('/v1/children')
        self.assertEqual(status,401)
        status,result=self.request('/v1/curriculum',token=self.child_token,pin=None)
        self.assertEqual(status,401)

    def test_trial_api_status_and_child_activation_protection(self):
        status,result=self.request('/v1/billing/trial',token=self.child_token,pin=None)
        self.assertEqual(status,200)
        self.assertEqual(result['status'],'active')
        status,result=self.request('/v1/billing/trial',{},token=self.child_token,pin=None,extra={'Idempotency-Key':'child-trial'})
        self.assertEqual(status,403)
        status,result=self.request('/v1/billing/trial',{},extra={'Idempotency-Key':'second-trial'})
        self.assertEqual(status,409)

    def test_admin_role_required_and_revision_checked(self):
        status,result=self.request('/v1/admin/tariff')
        self.assertEqual(status,403)
        repo=Repository(self.database)
        parent=repo.authenticate(self.token,'123456',True)
        from backend.domain import now
        with repo.db:repo.db.execute('INSERT INTO administrator_roles VALUES (?,?)',(parent['family_id'],now()))
        repo.close()
        status,result=self.request('/v1/admin/tariff')
        self.assertEqual(status,200)
        status,result=self.request('/v1/admin/tariff',{'name':'Тестовый','price_per_child_kzt':15000,'max_saved_profiles':5},extra={'If-Match':'"1"'})
        self.assertEqual(status,200)
        self.assertEqual(result['revision'],2)
        status,quote=self.request('/v1/billing/quote',{'child_ids':[self.children[0]['id']]})
        self.assertEqual(quote['total_amount'],15000)
        status,result=self.request('/v1/admin/tariff',{'name':'Старая версия','price_per_child_kzt':1,'max_saved_profiles':5},extra={'If-Match':'"1"'})
        self.assertEqual(status,409)
        status,audit=self.request('/v1/admin/tariff/audit')
        self.assertEqual(status,200)
        self.assertEqual(len(audit),1)

    def test_static_and_health(self):
        with urlopen(self.base+'/') as response:
            self.assertIn('AI Репетитор',response.read().decode())
        status,result=self.request('/health')
        self.assertEqual(status,200)

    def test_api_revision_and_deduplication_contract(self):
        status,session=self.request('/v1/sessions',{'lesson_id':'engineering-addition-v1'},self.child_token,None,{'Idempotency-Key':'start'})
        self.assertEqual(status,200)
        payload={'client_event_id':'answer','task_revision':1,'step_id':'step_0','input':{'type':'choice','value':7}}
        headers={'If-Match':'"1"','Idempotency-Key':'answer'}
        status,result=self.request('/v1/sessions/'+session['id']+'/attempts',payload,self.child_token,None,headers)
        self.assertEqual(status,200)
        self.assertEqual(result['evaluation'],'correct')
        status,duplicate=self.request('/v1/sessions/'+session['id']+'/attempts',payload,self.child_token,None,headers)
        self.assertEqual(result,duplicate)

    def test_privacy_export_route_is_scoped_and_requires_password(self):
        status,_=self.request('/v1/privacy/exports',{},extra={'Idempotency-Key':'export-http'})
        self.assertEqual(status,401)
        status,proof=self.request('/v1/privacy/reauth',{'purpose':'export','password':'test-password-long'})
        self.assertEqual(status,200)
        status,job=self.request('/v1/privacy/exports',{'reauth_token':proof['reauth_token']},extra={'Idempotency-Key':'export-http'})
        self.assertEqual(status,200)
        from backend.privacy import PrivacyService
        repo=Repository(self.database);PrivacyService(repo).worker();repo.close()
        status,export=self.request('/v1/privacy/jobs/'+job['id']+'/download')
        self.assertEqual(status,200);self.assertEqual(len(export['children']),3)
        status,_=self.request('/v1/privacy/jobs/'+job['id'],token=self.other_token,pin='987654')
        self.assertEqual(status,404)
        status,_=self.request('/v1/privacy/jobs',token=self.child_token,pin=None)
        self.assertEqual(status,403)
    def test_family_deletion_retry_survives_token_revocation_without_new_authority(self):
        status,proof=self.request('/v1/privacy/reauth',{'purpose':'deletion','password':'test-password-long'})
        body={'reauth_token':proof['reauth_token'],'confirmation':'DELETE'}
        status,job=self.request('/v1/privacy/deletions',body,extra={'Idempotency-Key':'delete-http'})
        self.assertEqual(status,200)
        status,replay=self.request('/v1/privacy/deletions',body,extra={'Idempotency-Key':'delete-http'})
        self.assertEqual(status,200);self.assertEqual(replay,job)
        status,_=self.request('/v1/children');self.assertEqual(status,401)
        status,_=self.request('/v1/privacy/deletions',dict(body,child_id='fake'),extra={'Idempotency-Key':'delete-http'})
        self.assertEqual(status,409)
        status,_=self.request('/v1/privacy/deletions',body,extra={'Idempotency-Key':'different-key'})
        self.assertEqual(status,401)
