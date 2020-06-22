#include "mapeditormain.h"
#include "ui_mapeditormain.h"

MapEditorMain::MapEditorMain(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MapEditorMain)
{
    ui->setupUi(this);
}

MapEditorMain::~MapEditorMain()
{
    delete ui;
}

