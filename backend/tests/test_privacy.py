import json
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from backend.domain import Repository, DomainError
from backend.privacy import PrivacyService

class PrivacyTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.repo=Repository(Path(self.tmp.name)/'privacy.sqlite');self.service=PrivacyService(self.repo)
        account=self.repo.register({'login':'parent-privacy','password':'test-password-long','pin':'123456'})
        self.token=account['token'];self.parent=self.repo.authenticate(self.token,'123456',True)
        self.repo.set_consent(self.parent,{'purpose':'learning','version':'engineering-v1','granted':True})
        self.child=self.repo.create_child(self.parent,{'nickname':'Сова','grade':1,'age_band':'6-7','instruction_language':'ru-KZ','avatar':'owl'})
        self.ctoken=self.repo.child_token(self.parent,self.child['id'])['token']
        self.child_auth=self.repo.authenticate(self.ctoken)
        self.other=self.repo.register({'login':'other-family','password':'other-password-long','pin':'654321'})
        self.other_auth=self.repo.authenticate(self.other['token'],'654321',True)
    def tearDown(self):self.repo.close();self.tmp.cleanup()
    def proof(self,purpose):return self.service.reauthenticate(self.parent,{'purpose':purpose,'password':'test-password-long'})['reauth_token']
    def test_pin_alone_cannot_export_and_child_cannot_reauthenticate(self):
        with self.assertRaises(DomainError):self.service.create(self.parent,{},'export','one')
        with self.assertRaises(DomainError):self.service.reauthenticate(self.child_auth,{'purpose':'export','password':'test-password-long'})
    def test_export_minimal_fields_ownership_and_expiry(self):
        job=self.service.create(self.parent,{'reauth_token':self.proof('export')},'export','one')
        self.assertEqual(job['state'],'queued');self.service.worker()
        export=self.service.download(self.parent,job['id']);encoded=json.dumps(export)
        self.assertEqual(len(export['children']),1)
        for forbidden in ('password_hash','pin_hash','token_hash','other-family','receipt_hash'):
            self.assertNotIn(forbidden,encoded)
        self.assertFalse(export['safety_fragments_included'])
        with self.assertRaises(DomainError):self.service.download(self.other_auth,job['id'])
        with patch('backend.privacy.time.time',return_value=time.time()+86401):
            with self.assertRaises(DomainError):self.service.download(self.parent,job['id'])
    def test_reauth_proof_is_session_bound_scoped_and_single_use(self):
        token=self.proof('export')
        with self.assertRaises(DomainError):self.service.create(self.other_auth,{'reauth_token':token},'export','a')
        with self.assertRaises(DomainError):self.service.create(self.parent,{'reauth_token':token,'confirmation':'DELETE'},'deletion','b')
        job=self.service.create(self.parent,{'reauth_token':token},'export','c')
        self.assertEqual(job,self.service.create(self.parent,{'reauth_token':token},'export','c'))
        with self.assertRaises(DomainError):self.service.create(self.parent,{'reauth_token':token},'export','d')
    def test_profile_deletion_revokes_child_and_preserves_family(self):
        job=self.service.create(self.parent,{'reauth_token':self.proof('deletion'),'child_id':self.child['id'],'confirmation':'DELETE'},'deletion','one')
        with self.assertRaises(DomainError):self.repo.authenticate(self.ctoken)
        self.repo.authenticate(self.token,'123456',True)
        self.service.worker();self.assertEqual(self.service.status(self.parent,job['id'])['state'],'completed')
        self.assertEqual(self.repo.children(self.parent),[])
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM deletion_ledger').fetchone()[0],1)
    def test_family_deletion_revokes_tokens_removes_profiles_and_receipt_survives(self):
        job=self.service.create(self.parent,{'reauth_token':self.proof('deletion'),'confirmation':'DELETE'},'deletion','one')
        with self.assertRaises(DomainError):self.repo.authenticate(self.token,'123456',True)
        with self.assertRaises(DomainError):self.service.receipt(job['id'],'wrong')
        self.service.worker()
        receipt=self.service.receipt(job['id'],job['receipt_token'])
        self.assertTrue(receipt['active_data_removed']);self.assertFalse(receipt['backup_sla_confirmed'])
        self.assertEqual(self.repo.children(self.parent),[])
        with self.assertRaises(DomainError):self.repo.login({'login':'parent-privacy','password':'test-password-long'})
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM consent_events WHERE family_id=?',(self.parent['family_id'],)).fetchone()[0],1)

    def test_backup_restore_replays_independent_ledger(self):
        import shutil
        from backend.backup import snapshot
        database=self.repo.database_path
        saved=snapshot(database,Path(self.tmp.name)/'before.sqlite')
        job=self.service.create(self.parent,{'reauth_token':self.proof('deletion'),'confirmation':'DELETE'},'deletion','restore-test')
        self.service.worker()
        self.repo.close()
        shutil.copyfile(saved,database)
        self.repo=Repository(database);self.service=PrivacyService(self.repo)
        self.assertEqual(self.repo.children(self.parent),[])
        with self.assertRaises(DomainError):self.repo.authenticate(self.token,'123456',True)
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM deletion_ledger').fetchone()[0],1)
