class RfidStatus {
  bool connectingStatus;
  String platformName;
  String getPower;
  String getTemperature;
  String getFrequencyMode;

  RfidStatus(
      {required this.connectingStatus,
      required this.platformName,
      required this.getPower,
      required this.getTemperature,
      required this.getFrequencyMode});

  String get formattedStatus {
    return '''RFID Status 
    \nConnectingStatus = $connectingStatus
    \nPlatform Name = $platformName
    \nPower Level (5-30)= $getPower 
    \nModule Temperature = $getTemperature
    \nFrequency Mode = $getFrequencyMode
    ''';
  }
}
