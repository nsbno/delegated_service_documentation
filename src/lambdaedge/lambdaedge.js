'use strict'

exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request
  const headers = request.headers

  const authUser = 'test'
  const authPass = 'pass'

  const encodedCredentials = new Buffer(`${authUser}:${authPass}`).toString('base64')
  const authString = `Basic ${encodedCredentials}`

  console.log("static pass");
  console.log('event dump ', event);  
  console.log('event headers ', headers);
  
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
  hash = headers.authorization[0].value
  pass = hash.toString('base64');
  console.log(pass)

  // Continue request processing if authentication passed
  callback(null, request)
}
