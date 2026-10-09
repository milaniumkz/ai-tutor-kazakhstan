"""Trusted local bootstrap. Never grant administrator privileges through public APIs."""
import argparse
import getpass
import os
from pathlib import Path
from backend.domain import Repository, DomainError, now

def main():
    parser=argparse.ArgumentParser(description='Создать отдельную административную учётную запись')
    parser.add_argument('--login',required=True)
    parser.add_argument('--role',choices=('admin','editor','method_reviewer','language_reviewer','publisher'),default='admin')
    args=parser.parse_args()
    password=getpass.getpass('Пароль администратора (от 10 символов): ')
    if password != getpass.getpass('Повторите пароль: '):
        parser.error('Пароли не совпадают')
    pin=getpass.getpass('Родительский PIN администратора (6 цифр): ')
    root=Path(__file__).resolve().parents[1]
    path=Path(os.getenv('TUTOR_DATABASE_PATH',str(root/'.local/tutor.sqlite')))
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    repo=Repository(path)
    try:
        account=repo.register({'login':args.login,'password':password,'pin':pin})
        with repo.db:
            if args.role=='admin':repo.db.execute('INSERT INTO administrator_roles VALUES (?,?)',(account['family_id'],now()))
            else:repo.db.execute('INSERT INTO content_roles VALUES (?,?)',(account['family_id'],args.role))
        path.chmod(0o600)
        print('Учётная запись с выбранной ролью создана. Войдите через родительский экран и подтвердите PIN.')
    except DomainError as error:
        parser.error(error.code)
    finally:
        repo.close()

if __name__=='__main__':main()
