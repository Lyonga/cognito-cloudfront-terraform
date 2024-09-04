import json
import boto3

ec2 = boto3.client('ec2')
sns = boto3.client('sns')

def lambda_handler(event, context):
    instance_id = event['detail']['instance-id']
    
    # Terminate the EC2 instance
    ec2.terminate_instances(InstanceIds=[instance_id])
    
    # Send SNS notification
    sns.publish(
        TopicArn = os.environ['SNS_TOPIC_ARN'],
        Message = f"Terminated non-compliant EC2 instance: {instance_id}"
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps(f"Terminated instance {instance_id} and notified Security team.")
    }
