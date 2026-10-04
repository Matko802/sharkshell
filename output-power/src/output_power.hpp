#pragma once

#include <QObject>

class OutputPower : public QObject {
  Q_OBJECT

public:
  explicit OutputPower(QObject* parent = nullptr);
  ~OutputPower() override;

  Q_INVOKABLE void setAllPower(bool on) const;
};