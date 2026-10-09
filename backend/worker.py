"""Trusted local runner for privacy jobs; production queue infrastructure is separate."""
import argparse
from pathlib import Path
from backend.domain import Repository
from backend.privacy import PrivacyService

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--database',required=True)
    parser.add_argument('--retry-job')
    parser.add_argument('--drain',action='store_true')
    args=parser.parse_args()
    if not Path(args.database).is_file():parser.error('Database does not exist')
    repo=Repository(args.database)
    try:
        if args.retry_job:
            with repo.db:
                cursor=repo.db.execute("UPDATE privacy_jobs SET state='queued' WHERE id=? AND state='failed'",(args.retry_job,))
                if cursor.rowcount!=1:parser.error('Retry requires an existing failed job')
        service=PrivacyService(repo)
        count=0
        while service.worker():
            count+=1
            if not args.drain or count>=100:break
        print('Completed local worker cycle; processed jobs:',count)
    finally:repo.close()

if __name__=='__main__':main()
