import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from backend.domain import Repository,DomainError,LESSON_ID,now

class TrialTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.path=Path(self.tmp.name)/'test.sqlite'
        self.repo=Repository(self.path)
        account=self.repo.register({'login':'trial-family','password':'test-password-long','pin':'123456'})
        self.parent=self.repo.authenticate(account['token'],'123456',True)
        self.repo.set_consent(self.parent,{'purpose':'learning','version':'engineering-v1','granted':True})
        self.child=self.repo.create_child(self.parent,{'nickname':'Сова','grade':1,'age_band':'6-7','instruction_language':'ru-KZ','avatar':'owl'})
        self.auth=self.repo.authenticate(self.repo.child_token(self.parent,self.child['id'])['token'])

    def tearDown(self):
        self.repo.close();self.tmp.cleanup()

    def test_three_days_exact_and_no_autocharge(self):
        self.assertEqual(self.repo.trial_status(self.parent)['status'],'eligible')
        trial=self.repo.activate_trial(self.parent,'trial-1')
        row=self.repo.db.execute('SELECT * FROM family_trials').fetchone()
        self.assertEqual(row['expires_at']-row['started_at'],3*86400)
        self.assertEqual(trial['duration_days'],3)
        self.assertFalse(trial['auto_renew'])
        self.assertFalse(trial['requires_payment_card'])

    def test_once_per_family_and_retries_do_not_extend(self):
        self.repo.activate_trial(self.parent,'trial-1')
        expires=self.repo.trial_status(self.parent)['expires_at']
        self.repo.activate_trial(self.parent,'trial-1')
        self.assertEqual(self.repo.trial_status(self.parent)['expires_at'],expires)
        with self.assertRaises(DomainError) as error:self.repo.activate_trial(self.parent,'trial-2')
        self.assertEqual(error.exception.code,'TRIAL_ALREADY_USED')

    def test_new_child_shares_same_expiration(self):
        self.repo.activate_trial(self.parent,'trial-1')
        expires=self.repo.trial_status(self.parent)['expires_at']
        child=self.repo.create_child(self.parent,{'nickname':'Лиса','grade':3,'age_band':'8-9','instruction_language':'ru-KZ','avatar':'fox'})
        auth=self.repo.authenticate(self.repo.child_token(self.parent,child['id'])['token'])
        self.assertEqual(self.repo.trial_status(auth)['expires_at'],expires)

    def test_child_cannot_activate_trial(self):
        with self.assertRaises(DomainError):self.repo.activate_trial(self.auth,'trial-1')

    def test_expiration_blocks_new_sessions_and_cannot_restart(self):
        trial=self.repo.activate_trial(self.parent,'trial-1')
        expires=self.repo.db.execute('SELECT expires_at FROM family_trials').fetchone()[0]
        with patch('backend.domain.time.time',return_value=expires):
            self.assertEqual(self.repo.trial_status(self.auth)['status'],'expired')
            with self.assertRaises(DomainError) as error:self.repo.start(self.auth,{'lesson_id':LESSON_ID},'start')
            self.assertEqual(error.exception.code,'ACCESS_REQUIRED')
            with self.assertRaises(DomainError):self.repo.activate_trial(self.parent,'new-trial')

    def test_admin_change_only_affects_new_trials(self):
        self.repo.activate_trial(self.parent,'trial-1')
        expires=self.repo.trial_status(self.parent)['expires_at']
        with self.repo.db:self.repo.db.execute('INSERT INTO administrator_roles VALUES (?,?)',(self.parent['family_id'],now()))
        self.repo.update_tariff(self.parent,{'name':'Тариф','price_per_child_kzt':10000,'max_saved_profiles':5,'trial_days':7},1)
        self.assertEqual(self.repo.trial_status(self.parent)['duration_days'],3)
        self.assertEqual(self.repo.trial_status(self.parent)['expires_at'],expires)
        account=self.repo.register({'login':'new-family','password':'test-password-long','pin':'123456'})
        other=self.repo.authenticate(account['token'],'123456',True)
        self.repo.set_consent(other,{'purpose':'learning','version':'engineering-v1','granted':True})
        self.assertEqual(self.repo.activate_trial(other,'trial')['duration_days'],7)

    def test_trial_survives_database_restart(self):
        trial=self.repo.activate_trial(self.parent,'trial-1')
        self.repo.close();self.repo=Repository(self.path)
        self.assertEqual(self.repo.trial_status(self.parent)['expires_at'],trial['expires_at'])

    def test_no_trial_no_new_lesson(self):
        with self.assertRaises(DomainError) as error:self.repo.start(self.auth,{'lesson_id':LESSON_ID},'start')
        self.assertEqual(error.exception.code,'ACCESS_REQUIRED')
