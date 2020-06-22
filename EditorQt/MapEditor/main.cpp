#include "mapeditormain.h"

#include <QApplication>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    MapEditorMain w;
    w.show();
    return a.exec();
}
