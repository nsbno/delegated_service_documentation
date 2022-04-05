import json
import boto3
import botocore
import os
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

def read_file_from_s3(s3_bucket):
  return "content"

def read_sqs(s3_bucket):
  return "content"

def updategit(about_file, aktivitetskode, api_gateway_arn, applicationname, 
      growthmetric, owner, servicesla, slack, swagger_file, technicalowner):
  print("Application name " + applicationname)
  cmd_to_run = (
      f"\n"
      f"# --- Download SSH key\n"
      f"mkdir -p ~/.ssh\n"
      f"\n"
      f"echo \"getting parameters\"\n"
      f"\n"
      f"aws ssm get-parameter \\\n"
      f"  --name antora_generated_servicedocumentation-git-deploy-key \\\n"
      f"  --region eu-west-1 \\\n"
      f"  --with-decryption \\\n"
      f"  --query Parameter.Value \\\n"
      f"  --output text \\\n"
      f"  > ~/.ssh/id_rsa\n"
      f"\n"
      f"chmod 600 ~/.ssh/id_rsa\n"
      f"\n"
      f"echo \"done!\"\n"
      f"\n"
      f"ssh-keyscan -H github.com >> ~/.ssh/known_hosts\n"
      f"\n"
      f"git config --global user.email \"machine-user@vy.no\"\n"
      f"git config --global user.name \"machine-user\"\n"
      f"\n"
      f"git clone git@github.com:nsbno/antora_generated_servicedocumentation --branch master\n"
      f"\n"
      f"cd ./antora_generated_servicedocumentation/services/\n"
      f"mkdir -p {applicationname}"
      f"\n"
      f"cd {applicationname}"
      f"\n"
      f"rm -f antora.yml\n"
      f"\n"
      f"echo \"Appending to file\"\n"
      f"\n"
      f"cat >> antora.yml << EOF\n"
      f"name: {applicationname}\n"
      f"version: ~\n"
      f""
      f"title: {applicationname} \n"
      f"\n"
      f"nav:\n"
      f"  - modules/ROOT/nav.adoc"
      f"\n"
      f"EOF\n"
      f"\n"
      f"git add antora.yml\n"
      f"\n"
      f"mkdir -p modules\n"
      f"cd modules\n" 
      f"\n"
      f"mkdir -p ROOT\n"
      f"cd ROOT\n" 
      f"rm -f nav.adoc\n"
      f"cat >> nav.adoc << EOF\n"
      f"* xref:ROOT:index.adoc[] \n"
      f"* xref:ROOT:api.adoc[API Reference] \n"
      f"EOF\n"
      f"\n"
      f"git add nav.adoc\n"
      f"\n"
      f"mkdir -p pages\n"
      f"cd pages\n"
      f"rm -f api.adoc\n"
      f"cat >> api.adoc << EOF\n"
      f"= API Reference\n"
      f":page-layout: swagger\n"
      f":page-swagger-url: https://developer.common-services.vydev.io/json/{applicationname}.json\n"
      f":reftext:"" {page-component-title}"
      f"\n"
      f"EOF\n"
      f"\n"
      f"git add api.adoc\n"
      f"\n"   
      f"rm -f index.adoc\n"
      f"cat >> index.adoc << EOF\n"
      f"= {applicationname}\n"
      f"EOF\n"
      f"\n"
      f"git add index.adoc\n"
      f"\n"   
      f"cd ../../../../../home/modules/ROOT/pages\n"
      f"if grep -c {applicationname}::api.adoc services.adoc; then\n"
      f"  echo 'service already added {applicationname}'\n"
      f"  else\n"     
      f"  echo 'in loop'\n"
      f"  head -n -1 services.adoc > tmp.txt && mv tmp.txt services.adoc\n"
      f"\n"
      f"  cat >> services.adoc << EOF\n"
      f"  |xref:{applicationname}::api.adoc[], Microservice \n"
      f"  |===\n"
      f"EOF\n"
      f"\n"
      f"  git add services.adoc\n"
      f"fi\n"
      
      
      
      f"git commit -m \"Update service doc for {applicationname}\"\n"
      f"git push\n"
  )  
  
  return cmd_to_run

def lambda_handler(event, context):
  s3 = boto3.client('s3')
#  logger.info("Raw event " +  str(event))
  logger.info(json.dumps(event, indent=4, sort_keys=True))
  s3bucket = ""
  s3path = ""


  try:
    eventrecord = str(event["Records"][0]["body"])
    eventrecor = json.loads(eventrecord)
    logger.info("eventrecor " +  str(eventrecor))
    logger.info("awsRegion record " +  str(eventrecor["Records"][0]["awsRegion"]))
    logger.info("name record " +  str(eventrecor["Records"][0]["s3"]["bucket"]["name"]))
    s3bucket = eventrecor["Records"][0]["s3"]["bucket"]["name"]
    logger.info("key record " +  str(eventrecor["Records"][0]["s3"]["object"]["key"]))
    s3path = eventrecor["Records"][0]["s3"]["object"]["key"]
    data = s3.get_object(Bucket=s3bucket, Key=s3path)
    contents = data['Body'].read()
    developerportalchanges = json.loads(contents.decode("utf-8"))
    gitresult = updategit(
        developerportalchanges["about_file"],
        developerportalchanges["aktivitetskode"],
        developerportalchanges["api_gateway_arn"],
        developerportalchanges["applicationname"],
        developerportalchanges["growthmetric"],
        developerportalchanges["owner"],
        developerportalchanges["servicesla"],
        developerportalchanges["slack"],
        developerportalchanges["swagger_file"],
        developerportalchanges["technicalowner"]
    )
  except botocore.exceptions.ClientError as e:
    logger.info(
    "Getting Servicedoc parameters failed " + str(e)
    )

  try:
    lamdba_client = boto3.client("lambda")
    response = lamdba_client.invoke(
        InvocationType='Event',
        FunctionName=os.environ["fargate_lambda_name"],
        Payload=json.dumps({
            "image": os.environ["image"],
            "cmd_to_run": gitresult,
            "subnets": json.loads(os.environ["subnets"]),
            "ecs_cluster": os.environ["ecs_cluster"],
            "task_role_arn": os.environ["task_role_arn"],
            "task_execution_role_arn": os.environ["task_execution_role_arn"],
            "fargate_lambda_name": os.environ["fargate_lambda_name"]
        })
    )
  except botocore.exceptions.ClientError as e:
    logger.info(
    "Updating developer portal repo failed " + str(e)
    )
    
  try:
    developerportalchanges = json.loads(contents.decode("utf-8"))
  except botocore.exceptions.ClientError as e:
    logger.info(
    "Updating confluence with service documetnation failed " + str(e)
    )
    
  return {
    'statusCode': 200,
    'body': json.dumps('Service parameters sent!')
  }
