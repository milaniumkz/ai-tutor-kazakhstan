"""Local development server for the persistent API and browser implementation."""
import json
import os
import re
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlsplit, parse_qs
from backend.domain import Repository, DomainError

ROOT = Path(__file__).resolve().parents[1]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # Never log credentials, profile names or request bodies.

    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Content-Length',str(len(body)))
        self.send_header('Cache-Control','no-store')
        self.send_header('X-Content-Type-Options','nosniff')
        self.end_headers()
        self.wfile.write(body)

    def handle_request(self):
        path = urlsplit(self.path).path
        if not path.startswith('/v1/') and path != '/health':
            return self.static(path)
        db = Repository(self.server.database_path)
        try:
            data = {}
            if self.command == 'POST':
                if not self.headers.get('Content-Type','').startswith('application/json'):
                    raise DomainError('VALIDATION_FAILED')
                length = int(self.headers.get('Content-Length','0'))
                if not 0 < length <= 8192:
                    raise DomainError('REQUEST_TOO_LARGE',413)
                data = json.loads(self.rfile.read(length))
                if not isinstance(data,dict):
                    raise DomainError('VALIDATION_FAILED')
            if path == '/health' and self.command == 'GET':
                return self.send_json(200, {'status':'ok','mode':'local-engineering','external_ai':False})
            if path in ('/v1/auth/register','/v1/auth/login') and self.command == 'POST':
                result = db.register(data) if path.endswith('register') else db.login(data)
                return self.send_json(201 if path.endswith('register') else 200,result)
            bearer = self.headers.get('Authorization','')
            if path=='/v1/privacy/deletions' and self.command=='POST' and bearer.startswith('Bearer '):
                from backend.privacy import PrivacyService
                replay=PrivacyService(db).replay_deletion(bearer[7:],data,self.headers.get('Idempotency-Key'))
                if replay:return self.send_json(200,replay)
            if re.fullmatch('/v1/privacy/receipts/[^/]+',path) and self.command=='GET':
                from backend.privacy import PrivacyService
                return self.send_json(200,PrivacyService(db).receipt(path.split('/')[-1],bearer.removeprefix('Bearer ')))
            if not bearer.startswith('Bearer '):
                raise DomainError('AUTH_REQUIRED',401)
            parent = path in ('/v1/children','/v1/consents','/v1/billing/quote') or (path == '/v1/billing/trial' and self.command == 'POST') or path.startswith('/v1/privacy/') or path.startswith('/v1/admin/') or path.endswith('/access') or (path == '/v1/progress' and self.headers.get('X-Parent-Pin') is not None)
            auth = db.authenticate(bearer[7:],self.headers.get('X-Parent-Pin'),parent)
            method = self.command
            if path == '/v1/privacy/reauth' and method=='POST':
                from backend.privacy import PrivacyService
                result=PrivacyService(db).reauthenticate(auth,data)
            elif path in ('/v1/privacy/exports','/v1/privacy/deletions') and method=='POST':
                from backend.privacy import PrivacyService
                result=PrivacyService(db).create(auth,data,'export' if path.endswith('exports') else 'deletion',self.headers.get('Idempotency-Key'))
            elif path=='/v1/privacy/jobs' and method=='GET':
                from backend.privacy import PrivacyService
                result=PrivacyService(db).status(auth)
            elif re.fullmatch('/v1/privacy/jobs/[^/]+(?:/download)?',path) and method=='GET':
                from backend.privacy import PrivacyService
                service=PrivacyService(db);job_id=path.split('/')[4]
                result=service.download(auth,job_id) if path.endswith('/download') else service.status(auth,job_id)
            elif path == '/v1/auth/logout' and method == 'POST':
                result = db.logout(auth)
            elif path == '/v1/children':
                result = db.children(auth) if method == 'GET' else db.create_child(auth,data)
            elif path == '/v1/consents':
                result = db.consents(auth) if method == 'GET' else db.set_consent(auth,data)
            elif re.fullmatch('/v1/children/[^/]+/access',path) and method == 'POST':
                result = db.child_token(auth,path.split('/')[3])
            elif path == '/v1/curriculum' and method == 'GET':
                result = db.curriculum(auth)
            elif path == '/v1/capabilities' and method == 'GET':
                result = {'voice':False,'ocr':False,'external_ai':False,'payments':False,
                          'reason':'PROVIDER_NOT_CONFIGURED'}
            elif path == '/v1/sessions' and method == 'POST':
                result = db.start(auth,data,self.headers.get('Idempotency-Key'))
            elif re.fullmatch('/v1/sessions/[^/]+',path) and method == 'GET':
                result = db.session(auth,path.split('/')[3])
            elif re.fullmatch('/v1/sessions/[^/]+/(attempts|hints|pause|resume|cancel)',path) and method == 'POST':
                revision = int(self.headers.get('If-Match','').strip('"'))
                session_id, action = path.split('/')[3:5]
                if action == 'attempts' and self.headers.get('Idempotency-Key') != data.get('client_event_id'):
                    raise DomainError('IDEMPOTENCY_KEY_REQUIRED')
                result = db.attempt(auth,session_id,data,revision) if action == 'attempts' else db.hint(auth,session_id,revision,self.headers.get('Idempotency-Key')) if action=='hints' else db.transition(auth,session_id,action,revision)
            elif path == '/v1/progress' and method == 'GET':
                query = parse_qs(urlsplit(self.path).query)
                result = db.progress(auth,query.get('child_id',[auth['child_id']])[0])
            elif path == '/v1/billing/quote' and method == 'POST':
                result = db.quote(auth,data)
            elif path == '/v1/billing/trial':
                result = db.trial_status(auth) if method == 'GET' else db.activate_trial(auth,self.headers.get('Idempotency-Key'))
            elif path == '/v1/admin/tariff':
                db.require_admin(auth)
                result = db.tariff() if method == 'GET' else db.update_tariff(auth,data,int(self.headers.get('If-Match','').strip('"')))
            elif path == '/v1/admin/tariff/audit' and method == 'GET':
                db.require_admin(auth)
                result = [dict(row) for row in db.db.execute('SELECT id,old_configuration,new_configuration,occurred_at FROM tariff_audit ORDER BY rowid DESC LIMIT 100')]
            elif path == '/v1/admin/curriculum' and method == 'GET':
                from backend.content import ContentService
                grade=parse_qs(urlsplit(self.path).query).get('grade',[None])[0]
                result=ContentService(db).curriculum(auth,int(grade) if grade else None)
            elif path == '/v1/admin/content':
                from backend.content import ContentService
                service=ContentService(db)
                result=service.list(auth) if method=='GET' else service.create(auth,data)
            elif re.fullmatch('/v1/admin/content/[^/]+(?:/(submit|review|publish|retire|rollback))?',path):
                from backend.content import ContentService
                service=ContentService(db);parts=path.split('/');lesson_id=parts[4]
                if len(parts)==5 and method=='GET':
                    service.require(auth,{'editor','method_reviewer','language_reviewer','publisher'})
                    result=service.get(lesson_id)
                elif len(parts)==6 and method=='POST':
                    operation=parts[5]
                    result=service.review(auth,lesson_id,data) if operation=='review' else getattr(service,operation)(auth,lesson_id)
                else:raise DomainError('NOT_FOUND',404)
            else:
                raise DomainError('NOT_FOUND',404)
            self.send_json(200,result)
        except DomainError as error:
            self.send_json(error.status,{'error':{'code':error.code,'message_key':error.code.lower(),
                'retryable':error.status in (429,503),'request_id':str(uuid.uuid4())}})
        except (ValueError,TypeError,KeyError):
            self.send_json(400,{'error':{'code':'VALIDATION_FAILED','message_key':'validation_failed',
                'retryable':False,'request_id':str(uuid.uuid4())}})
        except Exception:
            self.send_json(500,{'error':{'code':'INTERNAL_ERROR','message_key':'try_again',
                'retryable':False,'request_id':str(uuid.uuid4())}})
        finally:
            db.close()

    def static(self,path):
        flutter = path == '/app' or path.startswith('/app/')
        root = (ROOT/('app/build/web' if flutter else 'web')).resolve()
        relative = path.removeprefix('/app') if flutter else path
        target = (root/relative.lstrip('/')).resolve()
        if not target.is_relative_to(root):
            return self.send_json(404,{'error':{'code':'NOT_FOUND'}})
        if not target.is_file():
            target = root/'index.html'
        if not target.is_file():
            return self.send_json(503,{'error':{'code':'CLIENT_NOT_BUILT'}})
        import mimetypes
        body = target.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type',mimetypes.guess_type(str(target))[0] or 'application/octet-stream')
        self.send_header('Content-Length',str(len(body)))
        self.send_header('X-Content-Type-Options','nosniff')
        self.end_headers()
        self.wfile.write(body)

    do_GET = handle_request
    do_POST = handle_request

class TutorServer(HTTPServer):
    def service_actions(self):
        from backend.privacy import PrivacyService
        repo=Repository(self.database_path)
        try:PrivacyService(repo).worker()
        except Exception:
            # No job payload or secrets enter logs. Ledger failures must never report successful deletion.
            with repo.db:
                repo.db.execute("UPDATE privacy_jobs SET state='failed' WHERE id=(SELECT id FROM privacy_jobs WHERE state='queued' ORDER BY rowid LIMIT 1)")
        finally:repo.close()

def serve():
    database = Path(os.getenv('TUTOR_DATABASE_PATH',str(ROOT/'.local/tutor.sqlite')))
    database.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    repo = Repository(database)
    repo.close()
    database.chmod(0o600)
    server = TutorServer(('127.0.0.1',int(os.getenv('PORT','8081'))),Handler)
    server.database_path = str(database)
    server.serve_forever()

if __name__ == '__main__':
    serve()
