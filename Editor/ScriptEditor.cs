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
using System.Diagnostics;
using DarkUI.Forms;
using DarkUI.Controls;

namespace Editor
{
    public partial class ScriptEditor : DarkForm
    {

        private string lastScriptPath = null;

        public ScriptEditor()
        {
            InitializeComponent();
        }

        private void quitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Close();
        }

        private void ScriptEditor_Load(object sender, EventArgs e)
        {
            CenterToParent();
            Initialize();
        }

        /**
         * 부모 디렉토리를 반환합니다.
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

        public void Initialize()
        {
            var parentDir = GetParentPath();

            var files = Directory.EnumerateFiles(Path.Combine(parentDir, "scripts"));
            foreach (var i in files)
            {
                // 스크립트 파일을 노드에 추가합니다.
                var node = new DarkTreeNode();
                node.Text = String.Format("{0}", Path.GetFileName(i));
                darkScriptTree.Nodes.Add(node);
            }

            InitWithScriptView(parentDir);
        }

        public void InitWithScriptView(string parentDir)
        {
            string htmlPath = Path.Combine(parentDir, "Editor").Replace("\\", "/");
            webBrowser1.Url = new Uri(String.Format("file:///{0}/res/ace/editor.html", htmlPath));
            webBrowser1.DocumentCompleted += WebBrowser1_DocumentCompleted; ;
            webBrowser1.ObjectForScripting = true;
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

        /**
         * 스크립트를 로드합니다.
         */
        public void LoadScript(string filename)
        {
            // 스크립트 파일이 있는지 확인합니다.
            string parentDir = GetParentPath();
            string targetFile = Path.Combine(parentDir, "scripts", filename);

            if (File.Exists(targetFile))
            {
                string contents = File.ReadAllText(targetFile);
                webBrowser1.Document.InvokeScript("loadScript", new object[] { contents });

                lastScriptPath = targetFile;
                toolStripStatusLabel1.Text = String.Format("스크립트 위치 : {0}", lastScriptPath);
            }
        }

        private void darkScriptTree_MouseDoubleClick(object sender, MouseEventArgs e)
        {
            var nodes = darkScriptTree.SelectedNodes;
            if (nodes.Count > 0)
            {
                var node = nodes.First();
                LoadScript(node.Text);

            }
        }

        private void OkButton_Click(object sender, EventArgs e)
        {
            Close();
        }

        private void CancelButton_Click(object sender, EventArgs e)
        {
            Close();
        }
    }
}
