import 'dart:io';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import 'device.dart';

void main() async {
  final String userPoolId = 'us-east-2_gKKEmo2AZ';
  final String clientId = '4haujdk5rakbefr0d6un6te675';
  final userPool = new CognitoUserPool(
    userPoolId,
    clientId,
  );

  final userId = 'vaibhavsultania81@gmail.com';
  final cognitoUser = new CognitoUser(userId, userPool);
  final authDetails = new AuthenticationDetails(
    username: userId,
    password: 'Xoriant123#',
  );
  var session;
  try {
    session = await cognitoUser.authenticateUser(authDetails);
  } catch (e) {
    print(e.toString());
  }

  final identityPoolId = 'us-east-2:f1f05f63-09ca-4746-8339-a6c74a98e5f9';
  final credentials = new CognitoCredentials(identityPoolId, userPool);
  await credentials.getAwsCredentials(session.getIdToken().getJwtToken());
  print(credentials.accessKeyId);
  print(credentials.secretAccessKey);
  print(credentials.sessionToken); //These you will get from Cognito
  final accessKey = credentials.accessKeyId;
  final secretAccessKey = credentials.secretAccessKey;
  final sessionToken = credentials.sessionToken;

  //This is your host. It's probably something like 'abcde191919-ats'
  const host = 'aj3729f6nylkb-ats';
  const region = 'us-east-2';
  //This is the ID of the AWS IoT device
  // const deviceId = 'arn:aws:iot:us-east-2:796044321264:thing/acSensor01';
  const deviceId = 'acSensor01';

  var device = AWSIoTDevice(region, accessKey, secretAccessKey, sessionToken, host);

  try {
    await device.connect(deviceId);
  } on Exception catch (e) {
    print(e.toString());
    print('Failed to connect, status is ${device.connectionStatus}');
    exit(-1);
  }

  device.messages.listen((message) {
    print('Received message on topic "${message.item1}", message is "${message.item2}"');
  });

  //The MQTT topic you want to subscribe to
  const topic = 'topic_1';

  device.subscribe(topic);

  device.publishMessage(topic, 'Hi!');
}
