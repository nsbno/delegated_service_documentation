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

exports.handler = async function (event, context, callback) {
  // Get request and request headers
  const request = event.Records[0].cf.request
  const headers = request.headers

  const SSMUser = 'antoraportaluser'
  const authUser = await asyncCalls(SSMUser);
  const SSMPass = 'antoraportalpass'
  const authPass = await asyncCalls(SSMPass)
  
  
    // Construct the Basic Auth string
    const authString = 'Basic ' + new Buffer(authUser + ':' + authPass).toString('base64');

    // Require Basic authentication
    if (typeof headers.authorization == 'undefined' || headers.authorization[0].value != authString) {
        const body = 'Unauthorized';
        const response = {
            status: '401',
            statusDescription: 'Unauthorized',
            body: body,
            headers: {
                'www-authenticate': [{key: 'WWW-Authenticate', value:'Basic'}]
            },
        };
        callback(null, response);
    }

    // Continue request processing if authentication passed
    callback(null, request);
};
