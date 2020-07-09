#include "mapeditormain.h"

#include <QApplication>
#include <QTextCodec>
#include <QMessageBox>
#include <QFile>
#include <QTextStream>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);

    MapEditorMain w;

    QFile f(":qdarkstyle/style.qss");

    if (!f.exists())   {
        printf("Unable to set stylesheet, file not found\n");
    }
    else   {
        f.open(QFile::ReadOnly | QFile::Text);
        QTextStream ts(&f);
        qApp->setStyleSheet(ts.readAll());
    }

    w.show();

    QTextCodec *pCodec = QTextCodec::codecForName("eucKR");
    w.setWindowTitle(pCodec->toUnicode("다크 모드 및 한글 출력 테스트"));
    w.setFixedSize(800, 600);

    return a.exec();
}
