import copy
import tempfile
import unittest
from pathlib import Path
from backend.domain import Repository, DomainError
from backend.content import ContentService, validate_lesson

class ContentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Repository(Path(self.tmp.name)/'test.sqlite')
        self.cms = ContentService(self.repo)
        self.auths = {}
        for role in ('editor','method_reviewer','language_reviewer','publisher'):
            user = self.repo.register({'login': role, 'password':'long-test-password', 'pin':'123456'})
            auth = self.repo.authenticate(user['token'], '123456', True)
            self.auths[role] = auth
            with self.repo.db:
                self.repo.db.execute('INSERT INTO content_roles VALUES (?,?)',(auth['family_id'],role))
        self.payload = copy.deepcopy(self.cms.list(self.auths['editor'])[0]['payload'])
    def tearDown(self):
        self.repo.close(); self.tmp.cleanup()
    def test_reference_answer_is_computed_not_trusted(self):
        self.payload['steps'][0]['answer'] += 1
        with self.assertRaises(DomainError) as error: validate_lesson(self.payload)
        self.assertEqual(error.exception.code,'REFERENCE_ANSWER_INVALID')
    def test_drafts_hidden_and_publication_requires_both_reviews(self):
        lesson = self.cms.create(self.auths['editor'], self.payload)
        self.assertEqual(self.cms.published(lesson['grade'],lesson['locale']), [])
        with self.assertRaises(DomainError):self.cms.publish(self.auths['publisher'],lesson['id'])
        self.cms.submit(self.auths['editor'],lesson['id'])
        with self.assertRaises(DomainError):self.cms.review(self.auths['method_reviewer'],lesson['id'],{'decision':'approve','notes':'Verified independently'})
        self.cms.review(self.auths['method_reviewer'],lesson['id'],{'decision':'approve','notes':'Verified independently','normative_applicability_checked':True})
        self.cms.review(self.auths['language_reviewer'],lesson['id'],{'decision':'approve','notes':'Language verified independently'})
        release=self.cms.publish(self.auths['publisher'],lesson['id'])
        public=self.cms.published(lesson['grade'],lesson['locale'])
        self.assertEqual(len(public),1)
        self.assertNotIn('answer',public[0])
        self.assertEqual(release['sha256'],lesson['payload_hash'])
        self.cms.retire(self.auths['publisher'],lesson['id'])
        self.assertEqual(self.cms.published(lesson['grade'],lesson['locale']),[])
    def test_author_cannot_review_their_own_material(self):
        lesson=self.cms.create(self.auths['editor'],self.payload)
        self.cms.submit(self.auths['editor'],lesson['id'])
        with self.repo.db:self.repo.db.execute('INSERT INTO content_roles VALUES (?,?)',(self.auths['editor']['family_id'],'method_reviewer'))
        with self.assertRaises(DomainError) as error:self.cms.review(self.auths['editor'],lesson['id'],{'decision':'approve','notes':'Verified independently','normative_applicability_checked':True})
        self.assertEqual(error.exception.code,'INDEPENDENT_REVIEW_REQUIRED')

    def approve(self,lesson):
        self.cms.submit(self.auths['editor'],lesson['id'])
        self.cms.review(self.auths['method_reviewer'],lesson['id'],{'decision':'approve','notes':'Verified independently','normative_applicability_checked':True})
        self.cms.review(self.auths['language_reviewer'],lesson['id'],{'decision':'approve','notes':'Language verified independently'})
    def test_author_cannot_publish_and_rollback_preserves_payload(self):
        first=self.cms.create(self.auths['editor'],self.payload);self.approve(first)
        with self.repo.db:self.repo.db.execute('INSERT INTO content_roles VALUES (?,?)',(self.auths['editor']['family_id'],'publisher'))
        with self.assertRaises(DomainError):self.cms.publish(self.auths['editor'],first['id'])
        self.cms.publish(self.auths['publisher'],first['id'])
        newer=copy.deepcopy(self.payload);newer['previous_version_id']=first['id'];newer['title']='New version title'
        second=self.cms.create(self.auths['editor'],newer);self.approve(second);self.cms.publish(self.auths['publisher'],second['id'])
        self.assertEqual(self.cms.get(first['id'])['status'],'retired')
        self.cms.rollback(self.auths['publisher'],first['id'])
        self.assertEqual(self.cms.get(first['id'])['payload_hash'],first['payload_hash'])
        self.assertEqual(self.cms.get(second['id'])['status'],'retired')
        self.assertEqual(self.repo.db.execute('SELECT count(*) FROM content_releases').fetchone()[0],3)
