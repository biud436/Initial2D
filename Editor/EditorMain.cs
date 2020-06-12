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

namespace Editor
{
    public partial class EditorMain : DarkForm
    {

        private Rectangle tileCurosr = new Rectangle(0, 0, 16, 16);

        public EditorMain()
        {
            InitializeComponent();
        }

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

        private void Initialize()
        {
            string parentDir = GetParentPath();

            string dataPath = Path.Combine(parentDir, "resources", "tiles", "tileset16-8x13.png");

            // 리소스 추가

            var files = Directory.EnumerateFiles(Path.Combine(parentDir, "scripts"));
            foreach(var i in files)
            {
                // 스크립트 파일을 노드에 추가합니다.
                var node = new DarkTreeNode();
                node.Text = String.Format("{0}", Path.GetFileName(i));
                darkScriptTreeView.Nodes.Add(node);
            }

            // 웹 브라우저
            string htmlPath = Path.Combine(parentDir, "Editor").Replace("\\", "/");
            webBrowser1.Url = new Uri(String.Format("file:///{0}/res/ace/editor.html", htmlPath));
            webBrowser1.DocumentCompleted += WebBrowser1_DocumentCompleted;
            webBrowser1.ObjectForScripting = true;

            var objectNode = new DarkTreeNode();
            objectNode.Text = String.Format("tileset:{0}", Path.GetFileName(dataPath));
            darkObjectTree.Nodes.Add(objectNode);

        }

        private void WebBrowser1_DocumentCompleted(object sender, WebBrowserDocumentCompletedEventArgs e)
        {
            LoadScript("main.lua");
        }

        public void SaveScript(string filename)
        {
            String text = webBrowser1.Document.InvokeScript(@"saveAs").ToString();
            File.WriteAllText(filename, text);
        }

        public void LoadScript(string filename)
        {
            // 스크립트 파일이 있는지 확인합니다.
            string parentDir = GetParentPath();
            string targetFile = Path.Combine(parentDir, "scripts", filename);

            if (File.Exists(targetFile))
            {
                string contents = File.ReadAllText(targetFile);
                webBrowser1.Document.InvokeScript("loadScript", new object[] { contents });
            }
        }

        // 맵에디터를 닫습니다.
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

        private void EditorMain_MouseMove(object sender, MouseEventArgs e)
        {
            int mx = e.X - 200;
            int my = e.Y - darkMenuStrip1.Height;
            int mapX = Math.Abs(mx / 32);
            int mapY = Math.Abs(my / 32);
            darkStatusStrip1.Items[0].Text = String.Format("맵 좌표 : {2}, {3} ({0}, {1})", mx, my, mapX, mapY);
        }

        private void darkSectionPanel1_MouseDown(object sender, MouseEventArgs e)
        {

        }

        private void pictureBox1_MouseClick(object sender, MouseEventArgs e)
        {
            tileCurosr.X = (e.X / 16) * 16;
            tileCurosr.Y = (e.Y / 16) * 16;

            pictureBox1.Invalidate();
        }

        private void pictureBox1_Paint(object sender, PaintEventArgs e)
        {
            var g = e.Graphics;

            Pen p = new Pen(Color.White);
            g.DrawRectangle(p, tileCurosr);
        }

        private void pictureBox1_Click(object sender, EventArgs e)
        {

        }

        private void darkScriptTreeView_DoubleClick(object sender, EventArgs e)
        {
            var nodes = darkScriptTreeView.SelectedNodes;
            if(nodes.Count > 0)
            {
                var node = nodes.First();
                LoadScript(node.Text);
            }
        }
    }
}
