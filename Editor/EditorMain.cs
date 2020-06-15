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
        private bool isReady = false;

        public EditorMain()
        {
            InitializeComponent();
        }

        /// <summary>
        /// 부모 디렉토리를 반환합니다.
        /// </summary>
        /// <returns></returns>
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
            // 오브젝트 뷰를 표시합니다 (임시 코드)
            string htmlPath = Path.Combine(parentDir, "Editor").Replace("\\", "/");
            webBrowser1.Url = new Uri(String.Format("file:///{0}/res/view/object-view.html", htmlPath));
            webBrowser1.DocumentCompleted += WebBrowser1_DocumentCompleted;
            webBrowser1.ObjectForScripting = true;
        }

        private void WebBrowser1_DocumentCompleted(object sender, WebBrowserDocumentCompletedEventArgs e)
        {
            
        }

        /// <summary>
        /// 프로젝트를 초기화합니다.
        /// </summary>
        private void Initialize()
        {
            // 프로젝트 만들기 창을 엽니다.
            OpenProjectEditorDialog();

            // 타일셋 이미지가 존재한다면 타일셋에 할당해야 합니다.
            var tilesetImage = DataManager.Instance.TilesetImage;
            if (File.Exists(tilesetImage))
            {
                pictureBox1.Image = Image.FromFile(tilesetImage);
            } else
            {
                if(pictureBox1.Image != null)
                {
                    pictureBox1.Image.Dispose();
                    pictureBox1.Image = null;
                }
            }

            // 임시 코드
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

            // 상태 창에 컴퓨터 명을 할당합니다 (임시 코드)
            darkStatusStrip1.Items[0].Text = Environment.UserDomainName;


            Initialize();
        }

        private void OnMouseMoveToTarget(object sender)
        {
            // 프로그램의 전체를 범위로 잡는 마우스 좌표.
            var pt = PointToClient(MousePosition);

            var db = DataManager.Instance;
            int mx = pt.X;
            int my = pt.Y;
            int tw = db.TileWidth;
            int th = db.TileHeight;

            // 마지막 맵 좌표를 표시한다.
            int mapX = Math.Abs(mouse.X / tw);
            int mapY = Math.Abs(mouse.Y / th);

            darkStatusStrip1.Items[0].Text = String.Format("맵 좌표 : {2}, {3} | 마우스 좌표 : {0}, {1} | 타일 크기 : {4} x {5} | 마우스 클릭 여부 : {6} | 타일 ID : {7}", mx, my, mapX, mapY, tw, th, isMouseLB.ToString(), lastTileId);
        }

        private void EditorMain_MouseMove(object sender, MouseEventArgs e)
        {

        }

        private void darkSectionPanel1_MouseDown(object sender, MouseEventArgs e)
        {

        }

        /// <summary>
        /// 타일의 커서를 옮깁니다.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
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

        /// <summary>
        /// 프로젝트 에디터를 엽니다.
        /// </summary>
        private void OpenProjectEditorDialog()
        {
            var projectEditor = new ProjectEditor();
            projectEditor.SetMainForm(this);
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

                // 이미지가 없는 경우에는 그릴 수 없게 합니다.
                if(pictureBox1.Image == null)
                {
                    return;
                }

                var mapCols = pictureBox1.Image.Width / tw;
                var mapRows = pictureBox1.Image.Height / th;
                var cursorCol = tileCurosr.X / tw;
                var cursorRow = (tileCurosr.Y / th);

                lastTileId = (cursorRow * mapCols) + cursorCol;
                int targetX = nx / tw;
                int targetY = ny / th;

                // 타일이 맵의 크기를 넘어서 그려지는 것을 방지합니다.
                if (targetY >= 0 && targetY < mapHeight && targetX >= 0 && targetX < mapWidth)
                {
                    DataManager.Instance.Layer1[targetY * mapWidth + targetX] = lastTileId;

                    tilemap.Invalidate(new Rectangle(nx, ny, tw, th), true);
                }
                
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

        /// <summary>
        /// 맵에 그리드 라인 표시하는 함수
        /// 백버퍼에 미리 그려 놓고 복사만 하는 방식을 사용하려 했으나, 적절한 방법을 찾지 못했습니다.
        /// 따라서 타일을 그릴 때 같이 그려집니다.   
        /// </summary>
        /// <param name="mainGraphics"></param>
        private void DrawGrid(Graphics mainGraphics)
        {
            Pen p = new Pen(Colors.BlueHighlight);

            var g = mainGraphics;
            var db = DataManager.Instance;
            List<Point> list = new List<Point>();

            var maxGridX = db.MapWidth * db.TileWidth;
            var maxGridY = db.MapHeight * db.TileHeight;

            for (int y = 0; y < maxGridY + 1; y += db.TileHeight)
            {
                list.Clear();
                list.Add(new Point(0, y));
                list.Add(new Point(maxGridX, y));
                g.DrawLines(p, list.ToArray());
            }

            for (int x = 0; x < maxGridX + 1; x += db.TileWidth)
            {
                list.Clear();
                list.Add(new Point(x, 0));
                list.Add(new Point(x, maxGridY));
                g.DrawLines(p, list.ToArray());
            }

            
        }

        private void tilemap_Paint(object sender, PaintEventArgs e)
        {
            var g = e.Graphics;

            if(!isReady)
            {
                InitWithTilemap(g);
                isReady = true;
                return;
            }

            // 마우스를 클릭하지 않았다면 실패
            if (!isMouseLB)
            {
                // 맵 그리드를 그립니다.
                DrawGrid(g);
                return;
            }

            var mx = mouse.X;
            var my = mouse.Y;
            var tw = DataManager.Instance.TileWidth;
            var th = DataManager.Instance.TileHeight;

            Image tilesetImage = pictureBox1.Image;
            Rectangle srcRect = tileCurosr;
            Rectangle destRect = new Rectangle(mx, my, tw, th);

            // 타일셋 이미지에서 특정 타일을 그립니다.
            g.DrawImage(tilesetImage, mx, my, srcRect, GraphicsUnit.Pixel);

            // 맵 그리드를 그립니다.
            DrawGrid(g);
        }

        private void InitWithTilemap(Graphics g)
        {
            int mapWidth = DataManager.Instance.MapWidth;
            int mapHeight = DataManager.Instance.MapHeight;

            var mx = mouse.X;
            var my = mouse.Y;
            var tw = DataManager.Instance.TileWidth;
            var th = DataManager.Instance.TileHeight;

            Image tilesetImage = pictureBox1.Image;
            
            var mapCols = pictureBox1.Image.Width / tw;
            var mapRows = pictureBox1.Image.Height / th;

            for (int y = 0; y < mapHeight; y++)
            {
                for(int x = 0; x < mapWidth; x++)
                {
                    var tileId = DataManager.Instance.Layer1[y * mapWidth + x];
                    var col = tileId % mapCols;
                    var row = Math.Abs(tileId / mapCols);
                    var nx = col * tw;
                    var ny = row * th;

                    Rectangle srcRect = new Rectangle(nx, ny, tw, th);
                    g.DrawImage(tilesetImage, x * tw, y * th, srcRect, GraphicsUnit.Pixel);

                }
            }

            DrawGrid(g);
        }

        private void tilemap_MouseMove(object sender, MouseEventArgs e)
        {
            OnDrawTilemap(e);
        }

        private void toolStripButton2_Click(object sender, EventArgs e)
        {
            DataManager.Instance.Save();
        }

        private void saveToolStripMenuItem_Click(object sender, EventArgs e)
        {
            DataManager.Instance.Save();
        }

        private void EditorMain_Activated(object sender, EventArgs e)
        {
            // 타일맵을 다시 그립니다.
            isReady = false;
        }
    }
}
