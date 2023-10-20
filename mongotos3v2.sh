#!/bin/sh

# change these variables to what you need
S3BUCKET=bucketname
FILENAME=filename
S3PATH=s3path
MONGODUMPPATH=dumppath
TMP_PATH=tmppath

TIMESTAMP=$(date +".%m.%d.%Y")
DAY=$(date +"%d")
DAYOFWEEK=$(date +"%A")
PERIOD=${1-day}

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

backup_database() {
    log "Starting backing up the database to a file..."
    mongodump --out ${MONGODUMPPATH} || { log "Failed to backup database"; exit 1; }
    log "Done backing up the database to a file."
}

compress_backup() {
    log "Starting compression..."
    tar cvzf ${TMP_PATH}${FILENAME}${TIMESTAMP}.tar.gz ${MONGODUMPPATH} || { log "Failed to compress backup"; exit 1; }
    log "Done compressing the backup file."
}

upload_backup() {
    log "Uploading the new backup..."
    s3cmd put -f ${TMP_PATH}${FILENAME}${TIMESTAMP}.tar.gz s3://${S3BUCKET}/${S3PATH}${PERIOD}/ || { log "Failed to upload backup"; exit 1; }
    log "New backup uploaded."
}

clean_old_backups() {
    log "Removing old backups (2 ${PERIOD}s ago)..."
    s3cmd del --recursive s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/ || { log "Failed to remove old backups"; exit 1; }
    log "Old backups removed."
}

move_past_backup() {
    log "Moving the backups from past $PERIOD to another folder..."
    s3cmd mv --recursive s3://${S3BUCKET}/${S3PATH}${PERIOD}/ s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/ || { log "Failed to move past backups"; exit 1; }
    log "Past backup moved."
}

remove_cache_files() {
    log "Removing the cache files..."
    rm -rf ${TMP_PATH} || { log "Failed to remove cache files"; exit 1; }
    log "Files removed."
}

main() {
    if [ ${PERIOD} = "auto" ]; then
        if [ ${DAY} = "01" ]; then
            PERIOD=month
        elif [ ${DAYOFWEEK} = "Sunday" ]; then
            PERIOD=week
        else
            PERIOD=day
        fi
    fi
    
    log "Selected period: $PERIOD."
    
    backup_database
    compress_backup
    upload_backup
    clean_old_backups
    move_past_backup
    remove_cache_files
    
    log "All done."
}

main
