#ifndef MAPEDITORMAIN_H
#define MAPEDITORMAIN_H

#include <QMainWindow>

QT_BEGIN_NAMESPACE
namespace Ui { class MapEditorMain; }
QT_END_NAMESPACE

class MapEditorMain : public QMainWindow
{
    Q_OBJECT

public:
    MapEditorMain(QWidget *parent = nullptr);
    ~MapEditorMain();

private:
    Ui::MapEditorMain *ui;
};
#endif // MAPEDITORMAIN_H
