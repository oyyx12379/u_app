//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <bluetooth_low_energy_windows/bluetooth_low_energy_windows_plugin_c_api.h>
#include <flutter_libserialport/flutter_libserialport_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  BluetoothLowEnergyWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BluetoothLowEnergyWindowsPluginCApi"));
  FlutterLibserialportPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterLibserialportPlugin"));
}
