import unittest
from backend.tests import test_domain as fixtures
from backend.domain import DomainError, now

class TariffTests(unittest.TestCase):
    setUp = fixtures.DomainTests.setUp
    tearDown = fixtures.DomainTests.tearDown
    # Only the dedicated tariff tests are collected from this class below.
    def test_administrator_role_is_not_self_assignable(self):
        self.assertFalse(self.repo.is_admin(self.parent['family_id']))
        with self.assertRaises(DomainError) as error:self.repo.update_tariff(self.parent,{'name':'Bad','price_per_child_kzt':1,'max_saved_profiles':5},1)
        self.assertEqual(error.exception.code,'ADMIN_AUTH_REQUIRED')

    def admin(self):
        with self.repo.db:self.repo.db.execute('INSERT INTO administrator_roles VALUES (?,?)',(self.parent['family_id'],now()))
        return self.parent

    def test_change_price_updates_quote_and_audit(self):
        data={'name':'Новый тариф','price_per_child_kzt':12000,'max_saved_profiles':5}
        result=self.repo.update_tariff(self.admin(),data,1)
        self.assertEqual(result['revision'],2)
        self.assertEqual(self.repo.quote(self.parent,{'child_ids':[self.child['id']]})['total_amount'],12000)
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM tariff_audit').fetchone()[0],1)
        with self.assertRaises(DomainError) as error:self.repo.update_tariff(self.parent,data,1)
        self.assertEqual(error.exception.code,'REVISION_CONFLICT')

    def test_invalid_tariff_and_profile_limit(self):
        auth=self.admin()
        for price in (0,-1,True,'10000',1000001):
            with self.assertRaises(DomainError):self.repo.update_tariff(auth,{'name':'Тариф','price_per_child_kzt':price,'max_saved_profiles':5},1)
        self.repo.update_tariff(auth,{'name':'Тариф','price_per_child_kzt':10000,'max_saved_profiles':1},1)
        with self.assertRaises(DomainError):self.repo.create_child(auth,{'nickname':'Лиса','grade':3,'age_band':'8-9','instruction_language':'ru-KZ','avatar':'fox'})
        self.assertEqual(len(self.repo.children(auth)),1)

    def test_tariff_changes_survive_database_restart(self):
        self.repo.update_tariff(self.admin(),{'name':'Сохранённый','price_per_child_kzt':11000,'max_saved_profiles':4},1)
        self.repo.close()
        from backend.domain import Repository
        self.repo=Repository(self.path)
        self.assertEqual(self.repo.tariff()['price_per_child_kzt'],11000)
