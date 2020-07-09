#ifndef MAPEDITORMAIN_H
#define MAPEDITORMAIN_H

#include <QMainWindow>
#include <QPoint>
#include <QImage>

QT_BEGIN_NAMESPACE
namespace Ui { class MapEditorMain; }
QT_END_NAMESPACE

class MapEditorMain : public QMainWindow
{
    Q_OBJECT

public:
    MapEditorMain(QWidget *parent = nullptr);
    ~MapEditorMain();

    void paintEvent(QPaintEvent *event);
    void mouseMoveEvent(QMouseEvent *event);
private slots:
    void exit();

private:
    Ui::MapEditorMain *ui;
    QPoint m_mouse;
    QImage m_image;

};
#endif // MAPEDITORMAIN_H
