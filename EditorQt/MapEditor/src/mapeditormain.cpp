#include "mapeditormain.h"
#include "ui_mapeditormain.h"
#include <QPainter>
#include <QMouseEvent>
#include <QStyleOption>
#include <QDir>
#include <QTextCodec>

MapEditorMain::MapEditorMain(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MapEditorMain)
    , m_mouse(0, 0)
    , m_image()
{
    ui->setupUi(this);

    setFixedSize(800, 600);
    setMouseTracking(true);

    m_image.load(R"(E:\VS2015\Projects\Initial2D\EditorQt\MapEditor\res\tilesets\tileset.png)");
}

MapEditorMain::~MapEditorMain()
{
    delete ui;
}

void MapEditorMain::exit()
{
    QApplication::exit();
}

void MapEditorMain::mouseMoveEvent(QMouseEvent *event)
{
    m_mouse = event->pos();
//    update();
    repaint();
}

void MapEditorMain::paintEvent(QPaintEvent *event)
{
    QPainter paint(this);

    paint.begin(this);

    QRect targetRect = QRect(0, 0, 16, 16);

    int tileID = 45;
    int dx = (tileID % 8) * 16;
    int dy = (tileID / 8) * 16;
    int mx = m_mouse.x();
    int my = m_mouse.y();
    int cx = rect().center().x();
    int cy = rect().center().y();

    QRect sourceRect = QRect(dx, dy, 16, 16);

    ui->centralwidget->setStyleSheet("background-color: rgba( 255, 255, 255, 0% );");

    paint.setViewport(0, 0, 17 * 16, 13 * 16);

    QMatrix mt(5, 0, 0, 5, cx, cy);
    paint.setMatrix(mt);

    for(int y = 0; y < 13; y++) {
        for(int x = 0; x < 17; x++) {
            targetRect.moveTo(0 + (x * 16), 0 + (y * 16));
            paint.drawImage(targetRect, m_image, sourceRect);
        }
    }

    QFont font("NanumGothic", 24);
    QFontMetrics measure(font);

    QTextCodec *pCodec = QTextCodec::codecForName("eucKR");
    QString targetText = pCodec->toUnicode("테스트");
    if(pCodec != 0) {
        paint.setFont(font);
        paint.drawText(
            mx - measure.width(targetText) / 2,
            my - measure.height() / 2,
            targetText
        );
    }

    paint.end();
}

