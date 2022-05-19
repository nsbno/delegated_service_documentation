'use strict'

const AWS = require('aws-sdk');
const ssm = new AWS.SSM({region: 'us-east-1'});

async function asyncCalls(ssmname) {
  const parameter = await ssm.getParameter({ 
      Name: ssmname, 
      WithDecryption: true 
  }).promise();
  const data = parameter.Parameter.Value;
  return data;
}

exports.handler = async  (event, context, callback) => {
  const request = event.Records[0].cf.request
  const headers = request.headers

  const SSMUser = 'antoraportaluser'
  const authUser = await asyncCalls(SSMUser);
  const SSMPass = 'antoraportalpass'
  const authPass = await asyncCalls(SSMPass)

  const encodedCredentials = new Buffer(`${authUser}:${authPass}`).toString('base64')
  const authString = `Basic ${encodedCredentials}`

  console.log('event dump ', event);  
  
  if (
    typeof headers.authorization == 'undefined' ||
    headers.authorization[0].value != authString
  ) {
    const response = {
      status: '401',
      statusDescription: 'Unauthorized',
      body: 'Unauthorized',
      headers: {
        'www-authenticate': [
          {
            key: 'WWW-Authenticate',
            value: 'Basic',
          }
        ]
      },
    }
    console.log("failed")
    callback(null, response)
    return
  }
  console.log("Completed")

  // Continue request processing if authentication passed
  callback(null, request)
}
