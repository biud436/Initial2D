using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using DarkUI.Forms;

namespace Editor
{
    public partial class ProjectEditor : DarkForm
    {

        private DarkForm mainForm;

        public ProjectEditor()
        {
            InitializeComponent();
            CenterToParent();
        }

        public void SetMainForm(ref DarkForm form)
        {
            mainForm = form;
        }

        private void darkButton1_Click(object sender, EventArgs e)
        {
            folderBrowserDialog1.SelectedPath = System.IO.Path.GetDirectoryName(Application.StartupPath);

            if (folderBrowserDialog1.ShowDialog() == DialogResult.OK)
            {
                DataManager.Instance.ProjectPath = folderBrowserDialog1.SelectedPath;
                darkTextBox1.Text = folderBrowserDialog1.SelectedPath;
            }
        }

        private void OnKeyPressEvent(object sender, KeyPressEventArgs e)
        {
            if (!char.IsControl(e.KeyChar) && !char.IsDigit(e.KeyChar) &&
                (e.KeyChar == '.'))
            {
                e.Handled = true;
            }
        }

        private void darkTileWidth_KeyPress(object sender, KeyPressEventArgs e)
        {
            OnKeyPressEvent(sender, e);
        }

        private void darkTileHeight_KeyPress(object sender, KeyPressEventArgs e)
        {
            OnKeyPressEvent(sender, e);
        }

        private void darkButtonOk_Click(object sender, EventArgs e)
        {
            Close();
        }

        private void ProjectEditor_FormClosing(object sender, FormClosingEventArgs e)
        {
            DataManager.Instance.TileWidth = int.Parse(darkTileWidth.Text);
            DataManager.Instance.TileHeight = int.Parse(darkTileHeight.Text);
        }

        private void ProjectEditor_Load(object sender, EventArgs e)
        {
            darkTextBox1.Text = DataManager.Instance.ProjectPath;
            darkTileWidth.Text = DataManager.Instance.TileWidth.ToString();
            darkTileHeight.Text = DataManager.Instance.TileHeight.ToString();
        }
    }
}
