"""Export S3 objects as a streaming tar.gz, without a local media mirror."""
from contextlib import closing
import os
import sys
import tarfile

import boto3
from botocore.config import Config


def main():
    bucket = os.environ['OPENPOST_BACKUP_S3_BUCKET']
    client = boto3.client(
        's3',
        endpoint_url=os.environ['RCLONE_CONFIG_OPENPOST_ENDPOINT'],
        region_name=os.environ['RCLONE_CONFIG_OPENPOST_REGION'] or 'auto',
        aws_access_key_id=os.environ['RCLONE_CONFIG_OPENPOST_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['RCLONE_CONFIG_OPENPOST_SECRET_ACCESS_KEY'],
        config=Config(signature_version='s3v4', s3={'addressing_style': 'path'},
                      connect_timeout=30, read_timeout=90),
    )

    def listing():
        return {item['Key']: (item['Size'], item['ETag'], item['LastModified'])
                for page in client.get_paginator('list_objects_v2').paginate(Bucket=bucket)
                for item in page.get('Contents', [])}

    with closing(client):
        objects = listing()
        with tarfile.open(fileobj=sys.stdout.buffer, mode='w|gz') as archive:
            for name, (size, etag, _) in objects.items():
                if name.startswith('/') or '..' in name.split('/'):
                    raise ValueError('unsafe object path')
                response = client.get_object(Bucket=bucket, Key=name, IfMatch=etag)
                with closing(response['Body']) as body:
                    if response['ContentLength'] != size:
                        raise RuntimeError('object changed size: ' + name)
                    member = tarfile.TarInfo('media/' + name)
                    member.size = size
                    member.mode = 0o600
                    archive.addfile(member, body)
                    if body.read(1):
                        raise RuntimeError('object exceeded listed size: ' + name)
        # Failed or changed sources must never send the receiver's commit frame.
        if objects != listing():
            raise RuntimeError('media object set changed during backup; retry later')


if __name__ == '__main__':
    main()
