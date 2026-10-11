#pragma once

#include <QObject>

class OutputPower : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
  Q_PROPERTY(bool available READ available NOTIFY availableChanged)
  Q_DISABLE_COPY(OutputPower)

public:
  explicit OutputPower(QObject* parent = nullptr);
  ~OutputPower() override;

  bool busy() const { return m_busy; }
  bool available() const { return m_available; }

  Q_INVOKABLE void setAllPower(bool on);

signals:
  void busyChanged();
  void availableChanged();
  void error(const QString& message);

private:
  void setBusy(bool b);
  void setAvailable(bool a);

  bool m_busy = false;
  bool m_available = false;
};
