"""Local SQLite snapshots. Deployment backup encryption/retention remain external."""
import argparse
import os
import sqlite3
from pathlib import Path
from backend.domain import Repository

def snapshot(database, destination):
    target=Path(destination)
    if target.exists():raise ValueError('Destination already exists')
    if Path(database).resolve()==target.resolve():raise ValueError('Choose a different destination')
    target.parent.mkdir(parents=True,exist_ok=True)
    descriptor=os.open(target,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    os.close(descriptor)
    source=Repository(database)
    output=sqlite3.connect(target)
    try:source.db.backup(output)
    finally:output.close();source.close()
    return target

def main():
    parser=argparse.ArgumentParser(description='Create a local snapshot; keep the separate deletion ledger during restoration.')
    parser.add_argument('--database',required=True);parser.add_argument('--output',required=True)
    args=parser.parse_args();snapshot(args.database,args.output)
    print('Snapshot created. Keep the independent deletion ledger; external encrypted storage and retention are not configured.')

if __name__=='__main__':main()
