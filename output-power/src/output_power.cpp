#include "output_power.hpp"

#include <QDebug>
#include <QList>
#include <wayland-client-core.h>

#include "wlr-output-power-management-unstable-v1-client-protocol.h"

namespace {

struct RegistryContext {
  QList<wl_output*> outputs;
  zwlr_output_power_manager_v1* manager = nullptr;
};

static void registryGlobal(void* data, wl_registry* registry, uint32_t id,
                           const char* interface, uint32_t version) {
  auto* ctx = static_cast<RegistryContext*>(data);
  if (qstrcmp(interface, wl_output_interface.name) == 0) {
    ctx->outputs.append(static_cast<wl_output*>(
        wl_registry_bind(registry, id, &wl_output_interface, qMin<quint32>(version, 4u))));
  } else if (qstrcmp(interface, zwlr_output_power_manager_v1_interface.name) == 0) {
    ctx->manager = static_cast<zwlr_output_power_manager_v1*>(
        wl_registry_bind(registry, id, &zwlr_output_power_manager_v1_interface, 1));
  }
}

static void registryRemove(void*, wl_registry*, uint32_t) {
}

const wl_registry_listener s_registryListener = {registryGlobal, registryRemove};

}

OutputPower::OutputPower(QObject* parent) : QObject(parent) {}

OutputPower::~OutputPower() = default;

void OutputPower::setBusy(bool b) {
  if (m_busy == b)
    return;
  m_busy = b;
  emit busyChanged();
}

void OutputPower::setAvailable(bool a) {
  if (m_available == a)
    return;
  m_available = a;
  emit availableChanged();
}

void OutputPower::setAllPower(bool on) {
  if (m_busy) {
    emit error(QStringLiteral("OutputPower: request already in flight"));
    return;
  }
  setBusy(true);

  wl_display* display = wl_display_connect(nullptr);
  if (!display) {
    qWarning("OutputPower: could not connect to Wayland display (WAYLAND_DISPLAY?)");
    emit error(QStringLiteral("could not connect to Wayland display"));
    setBusy(false);
    return;
  }

  RegistryContext ctx;
  wl_registry* registry = wl_display_get_registry(display);
  if (!registry) {
    wl_display_disconnect(display);
    setBusy(false);
    return;
  }
  wl_registry_add_listener(registry, &s_registryListener, &ctx);
  wl_display_roundtrip(display);
  wl_display_roundtrip(display);

  if (!ctx.manager) {
    qWarning("OutputPower: compositor does not offer zwlr_output_power_manager_v1");
    emit error(QStringLiteral("compositor does not offer zwlr_output_power_manager_v1"));
    setAvailable(false);
  } else {
    setAvailable(true);
    const auto mode = on ? ZWLR_OUTPUT_POWER_V1_MODE_ON : ZWLR_OUTPUT_POWER_V1_MODE_OFF;
    QList<zwlr_output_power_v1*> powers;
    powers.reserve(ctx.outputs.size());
    for (wl_output* output : ctx.outputs) {
      auto* power = zwlr_output_power_manager_v1_get_output_power(ctx.manager, output);
      if (power) {
        zwlr_output_power_v1_set_mode(power, mode);
        powers.append(power);
      }
    }
    if (!powers.isEmpty())
      wl_display_roundtrip(display);
    for (auto* power : powers)
      zwlr_output_power_v1_destroy(power);
  }

  for (wl_output* output : ctx.outputs)
    wl_output_release(output);
  if (ctx.manager)
    zwlr_output_power_manager_v1_destroy(ctx.manager);
  wl_registry_destroy(registry);
  wl_display_disconnect(display);
  setBusy(false);
}
