#!/usr/bin/env python
#
# Copyright (C) 2021 Vy
#
# Distributed under terms of the MIT license.

"""
Lambda function that forwards S3 bucket events to an SQS FIFO queue, as it
is currently not possible to directly use an SQS FIFO queue as a destination
for S3 events.
"""


import json
import logging
import os
import boto3

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

SQS = boto3.client("sqs")
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]


def lambda_handler(event, context):
    # TODO: Forward errors to Slack -- the S3 event must be processed at a later time!
    logger.debug(json.dumps(event, indent=4, sort_keys=True))
    response = SQS.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(event),
        MessageGroupId="s3-event",
    )
