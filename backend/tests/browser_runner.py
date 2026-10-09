"""Run browser checks against an isolated temporary database and test administrator."""
import os
import secrets
import subprocess
import tempfile
import threading
from http.server import HTTPServer
from pathlib import Path
from backend.application import Handler, TutorServer
from backend.domain import Repository, now

def main():
    root=Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='tutor-browser-') as directory:
        path=str(Path(directory)/'test.sqlite')
        repo=Repository(path)
        login='ephemeral-admin-'+secrets.token_hex(8)
        password=secrets.token_urlsafe(24)
        pin='123456'  # Synthetic test fixture, never a production account.
        account=repo.register({'login':login,'password':password,'pin':pin})
        with repo.db:
            repo.db.execute('INSERT INTO administrator_roles VALUES (?,?)',(account['family_id'],now()))
        repo.close()
        server=TutorServer(('127.0.0.1',0),Handler)
        server.database_path=path
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        environment=dict(os.environ,TUTOR_BASE_URL='http://127.0.0.1:'+str(server.server_port),
            TUTOR_TEST_ADMIN_LOGIN=login,TUTOR_TEST_ADMIN_PASSWORD=password,TUTOR_TEST_ADMIN_PIN=pin)
        # The temporary database always starts with the approved default tariff.
        environment.pop('TUTOR_EXPECT_TOTAL',None)
        try:
            for script in ('smoke.cjs','admin.cjs','privacy.cjs'):
                subprocess.run(['node',str(root/'web/tests'/script)],cwd=root,env=environment,check=True)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

if __name__=='__main__':main()
