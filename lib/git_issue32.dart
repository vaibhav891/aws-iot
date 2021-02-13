import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

void connect() async {
  final String signedV4Query =
      'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHBZ22PHAWZWW6MA%2F20180907%2Fap-southeast-1%2Fiotdevicegateway%2Faws4_request&X-Amz-Date=20180907T042308Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=69b39751dd11dee1102d7f89997f0a747396bb7989c398cea774961454ee5eb8';
  final MqttClient client =
      new MqttClient("wss://azg8fnwzpxzp0.iot.ap-southeast-1.amazonaws.com/mqtt?$signedV4Query", "");
  client.useWebSocket = true;
  client.port = 443;
  client.keepAlivePeriod = 30;
  client.secure = true;
  client.logging(true);
  //client.setProtocolV311(); //Tried to uncomment same result

  client.onDisconnected = () {
    debugPrint("DISCONNECTED!");
  };

  try {
    debugPrint('CONNECTING...');
    await client.connect();
    debugPrint('CONNECTED!');
  } catch (err) {
    debugPrint("ERROR! $err");
    client.disconnect();
  }
}
