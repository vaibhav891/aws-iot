import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:tuple/tuple.dart';

class AWSIoTDevice {
  // ignore: non_constant_identifier_names
  final _SERVICE_NAME = 'iotdevicegateway';
  // ignore: non_constant_identifier_names
  final _AWS4_REQUEST = 'aws4_request';
  // ignore: non_constant_identifier_names
  final _AWS4_HMAC_SHA256 = 'AWS4-HMAC-SHA256';
  // ignore: non_constant_identifier_names
  final _SCHEME = 'wss://';

  String _region;
  String _accessKeyId;
  String _secretAccessKey;
  String _sessionToken;
  String _host;
  bool _logging;

  var _onConnected;
  var _onDisconnected;
  var _onSubscribed;
  var _onSubscribeFail;
  var _onUnsubscribed;

  get onConnected => _onConnected;
  set onConnected(val) => _client?.onConnected = _onConnected = val;
  get onDisconnected => _onDisconnected;
  set onDisconnected(val) => _client?.onDisconnected = _onDisconnected = val;
  get onSubscribed => _onSubscribed;
  set onSubscribed(val) => _client?.onSubscribed = _onSubscribed = val;
  get onSubscribeFail => _onSubscribeFail;
  set onSubscribeFail(val) => _client?.onSubscribeFail = _onSubscribeFail = val;
  get onUnsubscribed => _onUnsubscribed;
  set onUnsubscribed(val) => _client?.onUnsubscribed = _onUnsubscribed = val;
  get connectionStatus => _client?.connectionStatus;

  MqttServerClient _client;

  StreamController<Tuple2<String, String>> _messagesController = StreamController<Tuple2<String, String>>();

  Stream<Tuple2<String, String>> get messages => _messagesController.stream;

  AWSIoTDevice(
    this._region,
    this._accessKeyId,
    this._secretAccessKey,
    this._sessionToken,
    String host, {
    bool logging: true,
    var onConnected,
    var onDisconnected,
    var onSubscribed,
    var onSubscribeFail,
    var onUnsubscribed,
  }) {
    _logging = logging;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    _onSubscribed = onSubscribed;
    _onSubscribeFail = onSubscribeFail;
    _onUnsubscribed = onUnsubscribed;

    if (host.contains('amazonaws.com')) {
      _host = host.split('.').first;
    } else {
      _host = host;
    }
  }

  Future<Null> connect(String clientId) async {
    if (_client == null) {
      _prepare(clientId);
    }

    try {
      await _client.connect();
    } on Exception catch (e) {
      _client.disconnect();
      throw e;
    }
    _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      for (MqttReceivedMessage<MqttMessage> message in c) {
        final MqttPublishMessage recMess = message.payload;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _messagesController.add(Tuple2<String, String>(message.topic, pt));
      }
    });
  }

  _prepare(String clientId) {
    final url = _prepareWebSocketUrl();
    _client = MqttServerClient(url, clientId);
    _client.logging(on: _logging);
    _client.useWebSocket = true;
    _client.port = 443;
    _client.connectionMessage = MqttConnectMessage().withClientIdentifier(clientId).keepAliveFor(300);
    _client.keepAlivePeriod = 300;
  }

  _prepareWebSocketUrl() {
    final now = _generateDatetime();
    final hostname = _buildHostname();

    final List creds = [
      this._accessKeyId,
      _getDate(now),
      this._region,
      this._SERVICE_NAME,
      this._AWS4_REQUEST,
    ];

    const payload = '';

    const path = '/\$aws/things/<thing name>/shadow/get';

    final queryParams = Map<String, String>.from({
      'X-Amz-Algorithm': _AWS4_HMAC_SHA256,
      'X-Amz-Credential': creds.join('/'),
      'X-Amz-Date': now,
      'X-Amz-SignedHeaders': 'host',
      'X-Amz-Expire': '86400',
    });

    final canonicalQueryString = SigV4.buildCanonicalQueryString(queryParams);
    final request = SigV4.buildCanonicalRequest(
        'GET',
        path,
        queryParams,
        Map.from({
          'host': hostname,
        }),
        payload);

    final hashedCanonicalRequest = SigV4.hashCanonicalRequest(request);
    final stringToSign =
        SigV4.buildStringToSign(now, SigV4.buildCredentialScope(now, _region, _SERVICE_NAME), hashedCanonicalRequest);

    final signingKey = SigV4.calculateSigningKey(_secretAccessKey, now, _region, _SERVICE_NAME);

    final signature = SigV4.calculateSignature(signingKey, stringToSign);

    final finalParams =
        '$canonicalQueryString&X-Amz-Signature=$signature&X-Amz-Security-Token=${Uri.encodeComponent(_sessionToken)}';

    return '$_SCHEME$hostname$path?$finalParams';
  }

  String _generateDatetime() {
    return new DateTime.now()
        .toUtc()
        .toString()
        .replaceAll(new RegExp(r'\.\d*Z$'), 'Z')
        .replaceAll(new RegExp(r'[:-]|\.\d{3}'), '')
        .split(' ')
        .join('T');
  }

  String _getDate(String dateTime) {
    return dateTime.substring(0, 8);
  }

  String _buildHostname() {
    return '$_host.iot.$_region.amazonaws.com';
  }

  void disconnect() {
    return _client.disconnect();
  }
}
