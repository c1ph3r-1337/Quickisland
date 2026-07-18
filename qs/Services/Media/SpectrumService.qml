pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property var spectrumObj: null

  Component.onCompleted: {
    createSpectrumObj();
  }

  function createSpectrumObj() {
    try {
      spectrumObj = Qt.createQmlObject(
        'import Quickshell; ' +
        'import Quickshell.Services.Pipewire; ' +
        'PwAudioSpectrum { ' +
        '  lowerCutoff: 50; ' +
        '  upperCutoff: 12000; ' +
        '  noiseReduction: 0.77; ' +
        '  smoothing: true; ' +
        '}',
        root,
        "dynamicSpectrum"
      );

      if (spectrumObj) {
        // Setup properties and dynamic bindings
        spectrumObj.node = Pipewire.defaultAudioSink;
        spectrumObj.enabled = Qt.binding(function() { return root._shouldRun; });
        spectrumObj.frameRate = Qt.binding(function() { return Settings.data.audio.spectrumFrameRate; });

        // Connect signals
        spectrumObj.valuesChanged.connect(function() {
          root.values = spectrumObj.values;
        });
        spectrumObj.idleChanged.connect(function() {
          root.isIdle = spectrumObj.idle;
        });

        _setBandsCount();
      }
    } catch (e) {
      Logger.d("Spectrum", "PwAudioSpectrum is not available. Audio spectrum visualizer will be disabled.");
    }
  }

  // Register a component that needs audio data, call this when a visualizer becomes active.
  // Pass a unique identifier (e.g., "lockscreen", "controlcenter:screen1", "plugin:fancy-audiovisualizer")
  function registerComponent(componentId) {
    root._registeredComponents[componentId] = true;
    root._registeredComponents = Object.assign({}, root._registeredComponents);
    Logger.d("Spectrum", "Component registered:", componentId, "- total:", root._registeredCount);
  }

  // Unregister a component when it no longer needs audio data.
  function unregisterComponent(componentId) {
    delete root._registeredComponents[componentId];
    root._registeredComponents = Object.assign({}, root._registeredComponents);
    Logger.d("Spectrum", "Component unregistered:", componentId, "- total:", root._registeredCount);
  }

  // Check if a component is registered
  function isRegistered(componentId) {
    return root._registeredComponents[componentId] === true;
  }

  // Component registration - any component needing audio data registers here
  property var _registeredComponents: ({})
  readonly property int _registeredCount: Object.keys(_registeredComponents).length
  property bool _shouldRun: _registeredCount > 0

  property var values: []
  property bool isIdle: true

  // TODO Remove in may 2026 - temporary until quickisland-qs is fully propagated
  Connections {
    target: Settings.data.audio
    function onSpectrumMirroredChanged() {
      _setBandsCount();
    }
  }
  function _setBandsCount() {
    if (!spectrumObj) return;
    const bandCount = Settings.data.audio.spectrumMirrored ? 32 : 64;
    if (spectrumObj.bandCount !== undefined) {
      spectrumObj.bandCount = bandCount;
    } else if (spectrumObj.barCount !== undefined) {
      spectrumObj.barCount = bandCount;
    }
  }
}
