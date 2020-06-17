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
        private TilemapControl tilemapControl;

        private DarkTreeNode mapNode;
        private DarkTreeNode resourceNode;

        public EditorMain()
        {
            InitializeComponent();
        }

        public void InitWithTilemapControl()
        {
            // 타일맵 컨트롤 생성
            tilemapControl = new TilemapControl();

            tilemap.Visible = false;
            panel2.Controls.Add(tilemapControl);
        }

        /// <summary>
        /// 부모 디렉토리를 반환합니다.
        /// </summary>
        /// <returns></returns>
        public string GetParentPath()
        {
            string editorRoot = DataManager.Instance.ProjectPath;
            string mainRoot = "";

            if (String.IsNullOrEmpty(editorRoot))
            {
                editorRoot = Directory.GetCurrentDirectory();
            }

            if (File.Exists(Path.Combine(editorRoot, "Editor.exe")))
            {
                mainRoot = Directory.GetParent(editorRoot).Parent.FullName;
            }
            else
            {
                mainRoot = editorRoot;
            }

            return mainRoot;
        }

        public void InitWithObjectView(string parentDir)
        {

        }

        private void WebBrowser1_DocumentCompleted(object sender, WebBrowserDocumentCompletedEventArgs e)
        {
            
        }

        /// <summary>
        /// 프로젝트를 초기화합니다.
        /// </summary>
        private void Initialize()
        {
            InitWithTilemapControl();

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

            // 맵 트리 추가
            InitWithMapTree();
        }

        private void InitWithMapTree()
        {
            string mainRoot = GetParentPath();

            // 리소스 노드
            resourceNode = new DarkTreeNode();
            resourceNode.Text = "resources";

            {
                var dirInfo = new DirectoryInfo(Path.Combine(mainRoot, "resources"));
                var dirs = dirInfo.GetDirectories();

                dirInfo.GetFiles().ToList().ForEach((file) =>
                {
                    var fileNode = new DarkTreeNode(file.Name);
                    resourceNode.Nodes.Add(fileNode);
                });

                foreach (var dir in dirs)
                {
                    var dirNode = new DarkTreeNode();
                    dirNode.Text = dir.Name;

                    resourceNode.Nodes.Add(dirNode);

                    dir.GetFiles().ToList().ForEach((file) =>
                    {
                        var fileNode = new DarkTreeNode(file.Name);
                        dirNode.Nodes.Add(fileNode);
                    });
                }
            }

            // 스크립트 노드
            var scriptsNode = new DarkTreeNode();
            scriptsNode.Text = "scripts";

            {
                var dirInfo = new DirectoryInfo(Path.Combine(mainRoot, "scripts"));
                var dirs = dirInfo.GetDirectories();

                dirInfo.GetFiles().ToList().ForEach((file) =>
                {
                    var fileNode = new DarkTreeNode(file.Name);
                    scriptsNode.Nodes.Add(fileNode);
                });

                foreach (var dir in dirs)
                {
                    var dirNode = new DarkTreeNode();
                    dirNode.Text = dir.Name;

                    scriptsNode.Nodes.Add(dirNode);

                    dir.GetFiles().ToList().ForEach((file) =>
                    {
                        var fileNode = new DarkTreeNode(file.Name);
                        dirNode.Nodes.Add(fileNode);
                    });
                }
            }

            darkMapTree.Nodes.Add(resourceNode);
            darkMapTree.Nodes.Add(scriptsNode);

            darkMapTree.ContextMenuStrip = contextMenuStrip1;
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

            tilemapControl.TileCurosr = new Rectangle(tileCurosr.X, tileCurosr.Y, tw, th);

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

            // 타일셋 이미지를 설정합니다.
            tilemapControl.TilesetImage = Image.FromFile(DataManager.Instance.TilesetImage);
            tilemapControl.Connect();
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
            //string contents = webBrowser1.Document.InvokeScript("OK").ToString();
            //MessageBox.Show(contents, Application.ProductName);
        }

        private void OnDrawTilemap(MouseEventArgs e)
        {
            
        }

        private void tilemap_MouseDown(object sender, MouseEventArgs e)
        {
            
        }

        private void tilemap_MouseUp(object sender, MouseEventArgs e)
        {
            
        }

        /// <summary>
        /// 맵에 그리드 라인 표시하는 함수
        /// 백버퍼에 미리 그려 놓고 복사만 하는 방식을 사용하려 했으나, 적절한 방법을 찾지 못했습니다.
        /// 따라서 타일을 그릴 때 같이 그려집니다.   
        /// </summary>
        /// <param name="mainGraphics"></param>
        private void DrawGrid(Graphics mainGraphics)
        {
            
        }

        private void tilemap_Paint(object sender, PaintEventArgs e)
        {

        }

        private void InitWithTilemap(Graphics g)
        {

        }

        private void tilemap_MouseMove(object sender, MouseEventArgs e)
        {

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
            tilemapControl.Flush();
        }

        private void darkMapTree_MouseDown(object sender, MouseEventArgs e)
        {
            if(e.Button == MouseButtons.Right)
            {
                
            }
        }

        private void darkMapTree_DoubleClick(object sender, EventArgs e)
        {
            // 선택된 노드를 찾습니다.
            var nodes = darkMapTree.SelectedNodes;
            var firstNode = nodes.First();

            if(firstNode != null)
            {
                var name = firstNode.Text;
                if(Path.GetExtension(name) == ".lua")
                {
                    var scriptEditor = new ScriptEditor();
                    scriptEditor.ShowDialog();
                } else
                {
                    MessageBox.Show(Path.Combine(GetParentPath(), firstNode.FullPath));
                }

            }

        }

        /// <summary>
        /// 게임을 실행합니다.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void toolStripButton8_Click(object sender, EventArgs e)
        {
            DataManager.Instance.Save();

            using (var process = new Process())
            {
                string path = Path.Combine(Directory.GetCurrentDirectory(), "Engine", "Initial2D.exe");
                ProcessStartInfo info = new ProcessStartInfo()
                {
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8,
                    FileName = path,
                    CreateNoWindow = false
                };

                info.WorkingDirectory = Path.Combine(Directory.GetCurrentDirectory(), "Engine");

                process.StartInfo = info;
                process.Start();
            }
        }
    }
}
