#pragma once

#include <QQmlExtensionPlugin>
#include <qqml.h>

class OutputPowerPlugin : public QQmlExtensionPlugin {
  Q_OBJECT
  Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
  Q_DISABLE_COPY(OutputPowerPlugin)

public:
  OutputPowerPlugin(QObject* parent = nullptr) : QQmlExtensionPlugin(parent) {}
  void registerTypes(const char* uri) override;
};
