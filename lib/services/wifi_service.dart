import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final WiFiScan _wifiScan = WiFiScan.instance;

  Future<int?> getCurrentConnectedRssi() async {
    final canGet = await _wifiScan.canGetScannedResults(askPermissions: false);
    if (canGet != CanGetScannedResults.yes) {
      return null;
    }

    final canStart = await _wifiScan.canStartScan(askPermissions: false);
    if (canStart == CanStartScan.yes) {
      await _wifiScan.startScan();
    }

    final currentBssid = (await _networkInfo.getWifiBSSID())?.toLowerCase();
    final currentSsid = _cleanSsid(await _networkInfo.getWifiName());

    final scanResults = await _wifiScan.getScannedResults();
    if (scanResults.isEmpty) {
      return null;
    }

    if (currentBssid != null && currentBssid.isNotEmpty) {
      for (final accessPoint in scanResults) {
        if (accessPoint.bssid.toLowerCase() == currentBssid) {
          return accessPoint.level;
        }
      }
    }

    if (currentSsid != null && currentSsid.isNotEmpty) {
      int? bestLevel;
      for (final accessPoint in scanResults) {
        if (_cleanSsid(accessPoint.ssid) == currentSsid) {
          bestLevel = bestLevel == null
              ? accessPoint.level
              : (accessPoint.level > bestLevel
                  ? accessPoint.level
                  : bestLevel);
        }
      }
      return bestLevel;
    }

    return null;
  }

  String? _cleanSsid(String? value) {
    if (value == null) {
      return null;
    }
    return value.replaceAll('"', '').trim();
  }
}
