#!/bin/sh

# change these variables to what you need
S3BUCKET=bucketname
FILENAME=filename
# the following line prefixes the backups with the defined directory. it must be blank or end with a /
S3PATH=s3path

MONGODUMPPATH=dumppath

TMP_PATH=tmppath

TIMESTAMP=$(date +".%m.%d.%Y")
DAY=$(date +"%d")
DAYOFWEEK=$(date +"%A")

PERIOD=${1-day}

if [ ${PERIOD} = "auto" ]; then
        if [ ${DAY} = "01" ]; then
                PERIOD=month
        elif [ ${DAYOFWEEK} = "Sunday" ]; then
                PERIOD=week
        else
                PERIOD=day
        fi
fi

echo "Selected period: $PERIOD."

echo "Starting backing up the database to a file..."

# dump mongo
mongodump --out ${MONGODUMPPATH}

echo "Done backing up the database to a file."
echo "Starting compression..."

tar cvzf ${TMP_PATH}${FILENAME}${TIMESTAMP}.tar.gz ${MONGODUMPPATH}

echo "Done compressing the backup file."

# we want at least two backups, two months, two weeks, and two days
echo "Removing old backups (2 ${PERIOD}s ago)..."
s3cmd del --recursive s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/
echo "Old backups removed."

echo "Moving the backups from past $PERIOD to another folder..."
s3cmd mv --recursive s3://${S3BUCKET}/${S3PATH}${PERIOD}/ s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/
echo "Past backup moved."

# upload mongo backup
echo "Uploading the new backup..."
s3cmd put -f ${TMP_PATH}${FILENAME}${TIMESTAMP}.tar.gz s3://${S3BUCKET}/${S3PATH}${PERIOD}/
echo "New backup uploaded."

echo "Removing the cache files..."
# remove tmp files
rm -rf ${TMP_PATH}
echo "Files removed."
echo "All done."
