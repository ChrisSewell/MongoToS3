import os
import subprocess
from datetime import datetime
import configparser
import argparse
import logging

# Configuration file
config = configparser.ConfigParser()
config.read('config.ini')

# Configuration values
S3BUCKET = config.get('Settings', 'S3BUCKET')
FILENAME = config.get('Settings', 'FILENAME')
S3PATH = config.get('Settings', 'S3PATH')
MONGODUMPPATH = config.get('Settings', 'MONGODUMPPATH')
TMP_PATH = config.get('Settings', 'TMP_PATH')

TIMESTAMP = datetime.now().strftime(".%m.%d.%Y")
DAY = datetime.now().strftime("%d")
DAYOFWEEK = datetime.now().strftime("%A")

# Set up logging
logging.basicConfig(filename='backup.log', level=logging.INFO, format='%(asctime)s - %(message)s')

class BackupManager:
    def __init__(self, period):
        self.period = period
    
    def backup_database(self):
        logging.info("Starting backing up the database to a file...")
        subprocess.run(['mongodump', '--out', MONGODUMPPATH], check=True)
        logging.info("Done backing up the database to a file.")
    
    def compress_backup(self):
        logging.info("Starting compression...")
        subprocess.run(['tar', 'cvzf', f"{TMP_PATH}{FILENAME}{TIMESTAMP}.tar.gz", MONGODUMPPATH], check=True)
        logging.info("Done compressing the backup file.")
    
    def upload_backup(self):
        logging.info("Uploading the new backup...")
        subprocess.run(['s3cmd', 'put', '-f', f"{TMP_PATH}{FILENAME}{TIMESTAMP}.tar.gz", f"s3://{S3BUCKET}/{S3PATH}{self.period}/"], check=True)
        logging.info("New backup uploaded.")
    
    def clean_old_backups(self):
        logging.info("Removing old backups (2 periods ago)...")
        subprocess.run(['s3cmd', 'del', '--recursive', f"s3://{S3BUCKET}/{S3PATH}previous_{self.period}/"], check=True)
        logging.info("Old backups removed.")
    
    def move_past_backup(self):
        logging.info("Moving the backups from past period to another folder...")
        subprocess.run(['s3cmd', 'mv', '--recursive', f"s3://{S3BUCKET}/{S3PATH}{self.period}/", f"s3://{S3BUCKET}/{S3PATH}previous_{self.period}/"], check=True)
        logging.info("Past backup moved.")
    
    def remove_cache_files(self):
        logging.info("Removing the cache files...")
        subprocess.run(['rm', '-rf', TMP_PATH], check=True)
        logging.info("Files removed.")
    
    def perform_backup(self):
        try:
            self.backup_database()
            self.compress_backup()
            self.upload_backup()
            self.clean_old_backups()
            self.move_past_backup()
            self.remove_cache_files()
            logging.info("All done.")
        except subprocess.CalledProcessError as e:
            logging.error(f"Error: {e}")
            exit(1)

def main():
    parser = argparse.ArgumentParser(description='Backup manager')
    parser.add_argument('-p', '--period', help='Backup period', default='day')
    args = parser.parse_args()
    
    period = args.period
    
    if period == 'auto':
        if DAY == '01':
            period = 'month'
        elif DAYOFWEEK == 'Sunday':
            period = 'week'
        else:
            period = 'day'
    
    logging.info(f"Selected period: {period}.")
    
    backup_manager = BackupManager(period)
    backup_manager.perform_backup()

if __name__ == "__main__":
    main()
