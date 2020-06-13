using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.IO;
using DarkUI.Collections;
using DarkUI.Config;
using DarkUI.Controls;
using DarkUI.Docking;
using DarkUI.Forms;
using DarkUI.Renderers;
using System.Collections;
using System.Diagnostics;

namespace Editor
{
    public partial class EditorMain : DarkForm
    {

        private Rectangle tileCurosr = new Rectangle(0, 0, 16, 16);
        private bool isMouseLB = false;
        private Point mouse = new Point(0, 0);
        private int lastTileId = 0;

        public EditorMain()
        {
            InitializeComponent();
        }

        /**
         * 부모 디렉토리의 반환합니다.
         */
        public string GetParentPath()
        {
            string currentDir = Directory.GetCurrentDirectory();
            string parentDir = Directory.GetParent(currentDir).ToString();

            for (int i = 0; i < 2; i++)
            {
                parentDir = Directory.GetParent(parentDir).ToString();
            }

            return parentDir;
        }

        public void InitWithObjectView(string parentDir)
        {
            string htmlPath = Path.Combine(parentDir, "Editor").Replace("\\", "/");
            webBrowser1.Url = new Uri(String.Format("file:///{0}/res/view/object-view.html", htmlPath));
            webBrowser1.DocumentCompleted += WebBrowser1_DocumentCompleted;
            webBrowser1.ObjectForScripting = true;
        }

        private void WebBrowser1_DocumentCompleted(object sender, WebBrowserDocumentCompletedEventArgs e)
        {
            
        }

        /**
         * 프로젝트를 초기화합니다.
         */
        private void Initialize()
        {
            string parentDir = GetParentPath();
            string dataPath = Path.Combine(parentDir, "resources", "tiles", "tileset16-8x13.png");
            InitWithObjectView(parentDir);
        }

        /**
         * 맵 에디터를 닫습니다.
         */
        private void quitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Application.Exit();
        }

        private void EditorMain_Load(object sender, EventArgs e)
        {
            CenterToScreen();
            darkStatusStrip1.Items[0].Text = Environment.UserDomainName;
            Initialize();
        }

        private void OnMouseMoveToTarget(object sender)
        {
            var pt = PointToClient(MousePosition);

            int mx = pt.X;
            int my = pt.Y;
            int tw = DataManager.Instance.TileWidth;
            int th = DataManager.Instance.TileHeight;
            int mapX = Math.Abs(mx / tw);
            int mapY = Math.Abs(my / th);
            darkStatusStrip1.Items[0].Text = String.Format("맵 좌표 : {2}, {3} | 마우스 좌표 : {0}, {1} | 타일 크기 : {4} x {5} | 마우스 클릭 여부 : {6} | 타일 ID : {7}", mx, my, mapX, mapY, tw, th, isMouseLB.ToString(), lastTileId);
        }

        private void EditorMain_MouseMove(object sender, MouseEventArgs e)
        {

        }

        private void darkSectionPanel1_MouseDown(object sender, MouseEventArgs e)
        {

        }

        private void pictureBox1_MouseClick(object sender, MouseEventArgs e)
        {
            int tw = DataManager.Instance.TileWidth;
            int th = DataManager.Instance.TileHeight;

            tileCurosr.X = (e.X / tw) * tw;
            tileCurosr.Y = (e.Y / th) * th;

            pictureBox1.Invalidate();
        }

        private void pictureBox1_Paint(object sender, PaintEventArgs e)
        {
            var g = e.Graphics;

            Pen p = new Pen(Color.White);
            g.DrawRectangle(p, tileCurosr);
        }

        /**
         * 프로젝트 에디터를 엽니다
         */
        private void OpenProjectEditorDialog()
        {
            var projectEditor = new ProjectEditor();
            projectEditor.ShowDialog();
        }

        private void newToolStripMenuItem_Click(object sender, EventArgs e)
        {
            OpenProjectEditorDialog();
        }

        private void toolStripButton1_Click(object sender, EventArgs e)
        {
            OpenProjectEditorDialog();
        }

        private void timer1_Tick(object sender, EventArgs e)
        {
            OnMouseMoveToTarget(sender);
        }

        private void toolStripButton3_Click(object sender, EventArgs e)
        {
            var scriptEditor = new ScriptEditor();
            scriptEditor.ShowDialog();
        }

        private void darkObjectAddButton_Click(object sender, EventArgs e)
        {
            string contents = webBrowser1.Document.InvokeScript("OK").ToString();
            MessageBox.Show(contents, Application.ProductName);
        }

        private void OnDrawTilemap(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                isMouseLB = true;
                var db = DataManager.Instance;
                var tw = db.TileWidth;
                var th = db.TileHeight;
                int nx = (e.X / tw) * tw;
                int ny = (e.Y / th) * th;
                mouse.X = nx;
                mouse.Y = ny;

                var mapWidth = db.MapWidth;
                var mapHeight = db.MapHeight;

                //(tileCurosr.X / tw);

                var mapCols = pictureBox1.Image.Width / tw;
                var mapRows = pictureBox1.Image.Height / th;
                var cursorCol = tileCurosr.X / tw;
                var cursorRow = (tileCurosr.Y / th);

                lastTileId = (cursorRow * mapCols) + cursorCol;
                db.Tilemap[cursorRow * mapWidth + cursorCol] = lastTileId;

                Debug.WriteLine("타일 ID : {0}", db.Tilemap[cursorRow * mapWidth + cursorCol]);

                tilemap.Invalidate(new Rectangle(nx, ny, tw, th), true);
            }
        }

        private void tilemap_MouseDown(object sender, MouseEventArgs e)
        {
            OnDrawTilemap(e);
        }

        private void tilemap_MouseUp(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                isMouseLB = false;
            }
        }

        private void tilemap_Paint(object sender, PaintEventArgs e)
        {
            // 마우스를 클릭하지 않았다면 실패
            if (!isMouseLB)
            {
                return;
            }

            var g = e.Graphics;

            var mx = mouse.X;
            var my = mouse.Y;
            var tw = DataManager.Instance.TileWidth;
            var th = DataManager.Instance.TileHeight;

            Image tilesetImage = pictureBox1.Image;
            Rectangle srcRect = tileCurosr;
            Rectangle destRect = new Rectangle(mx, my, tw, th);

            g.DrawImage(tilesetImage, mx, my, srcRect, GraphicsUnit.Pixel);
        }

        private void tilemap_MouseMove(object sender, MouseEventArgs e)
        {
            OnDrawTilemap(e);
        }
    }
}
