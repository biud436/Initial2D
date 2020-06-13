namespace Editor
{
    partial class ProjectEditor
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.panel1 = new System.Windows.Forms.Panel();
            this.panel4 = new System.Windows.Forms.Panel();
            this.darkButtonOk = new DarkUI.Controls.DarkButton();
            this.panel3 = new System.Windows.Forms.Panel();
            this.darkTileHeight = new DarkUI.Controls.DarkTextBox();
            this.darkTileWidth = new DarkUI.Controls.DarkTextBox();
            this.darkButton1 = new DarkUI.Controls.DarkButton();
            this.darkTextBox1 = new DarkUI.Controls.DarkTextBox();
            this.panel2 = new System.Windows.Forms.Panel();
            this.darkLabel3 = new DarkUI.Controls.DarkLabel();
            this.darkLabel2 = new DarkUI.Controls.DarkLabel();
            this.darkLabel1 = new DarkUI.Controls.DarkLabel();
            this.folderBrowserDialog1 = new System.Windows.Forms.FolderBrowserDialog();
            this.darkLabel4 = new DarkUI.Controls.DarkLabel();
            this.openFileDialog1 = new System.Windows.Forms.OpenFileDialog();
            this.darkTilesetOpenButton = new DarkUI.Controls.DarkButton();
            this.darkTileset = new DarkUI.Controls.DarkTextBox();
            this.darkLabel5 = new DarkUI.Controls.DarkLabel();
            this.darkLabel6 = new DarkUI.Controls.DarkLabel();
            this.darkMapHeight = new DarkUI.Controls.DarkTextBox();
            this.darkMapWidth = new DarkUI.Controls.DarkTextBox();
            this.panel1.SuspendLayout();
            this.panel4.SuspendLayout();
            this.panel3.SuspendLayout();
            this.panel2.SuspendLayout();
            this.SuspendLayout();
            // 
            // panel1
            // 
            this.panel1.Controls.Add(this.panel4);
            this.panel1.Controls.Add(this.panel3);
            this.panel1.Controls.Add(this.panel2);
            this.panel1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.panel1.Location = new System.Drawing.Point(0, 0);
            this.panel1.Name = "panel1";
            this.panel1.Size = new System.Drawing.Size(437, 363);
            this.panel1.TabIndex = 0;
            // 
            // panel4
            // 
            this.panel4.Controls.Add(this.darkButtonOk);
            this.panel4.Dock = System.Windows.Forms.DockStyle.Bottom;
            this.panel4.Location = new System.Drawing.Point(0, 314);
            this.panel4.Name = "panel4";
            this.panel4.Size = new System.Drawing.Size(437, 49);
            this.panel4.TabIndex = 2;
            // 
            // darkButtonOk
            // 
            this.darkButtonOk.Location = new System.Drawing.Point(312, 10);
            this.darkButtonOk.Name = "darkButtonOk";
            this.darkButtonOk.Padding = new System.Windows.Forms.Padding(5);
            this.darkButtonOk.Size = new System.Drawing.Size(111, 36);
            this.darkButtonOk.TabIndex = 0;
            this.darkButtonOk.Text = "OK";
            this.darkButtonOk.Click += new System.EventHandler(this.darkButtonOk_Click);
            // 
            // panel3
            // 
            this.panel3.Controls.Add(this.darkMapHeight);
            this.panel3.Controls.Add(this.darkMapWidth);
            this.panel3.Controls.Add(this.darkTilesetOpenButton);
            this.panel3.Controls.Add(this.darkTileset);
            this.panel3.Controls.Add(this.darkTileHeight);
            this.panel3.Controls.Add(this.darkTileWidth);
            this.panel3.Controls.Add(this.darkButton1);
            this.panel3.Controls.Add(this.darkTextBox1);
            this.panel3.Location = new System.Drawing.Point(128, 8);
            this.panel3.Name = "panel3";
            this.panel3.Size = new System.Drawing.Size(295, 300);
            this.panel3.TabIndex = 1;
            // 
            // darkTileHeight
            // 
            this.darkTileHeight.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(69)))), ((int)(((byte)(73)))), ((int)(((byte)(74)))));
            this.darkTileHeight.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.darkTileHeight.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkTileHeight.Location = new System.Drawing.Point(4, 72);
            this.darkTileHeight.Name = "darkTileHeight";
            this.darkTileHeight.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.darkTileHeight.Size = new System.Drawing.Size(282, 21);
            this.darkTileHeight.TabIndex = 3;
            this.darkTileHeight.Text = "32";
            this.darkTileHeight.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.darkTileHeight.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.darkTileHeight_KeyPress);
            // 
            // darkTileWidth
            // 
            this.darkTileWidth.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(69)))), ((int)(((byte)(73)))), ((int)(((byte)(74)))));
            this.darkTileWidth.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.darkTileWidth.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkTileWidth.Location = new System.Drawing.Point(3, 37);
            this.darkTileWidth.Name = "darkTileWidth";
            this.darkTileWidth.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.darkTileWidth.Size = new System.Drawing.Size(282, 21);
            this.darkTileWidth.TabIndex = 2;
            this.darkTileWidth.Text = "32";
            this.darkTileWidth.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.darkTileWidth.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.darkTileWidth_KeyPress);
            // 
            // darkButton1
            // 
            this.darkButton1.Location = new System.Drawing.Point(231, 3);
            this.darkButton1.Name = "darkButton1";
            this.darkButton1.Padding = new System.Windows.Forms.Padding(5);
            this.darkButton1.Size = new System.Drawing.Size(54, 23);
            this.darkButton1.TabIndex = 1;
            this.darkButton1.Text = "Open";
            this.darkButton1.Click += new System.EventHandler(this.darkButton1_Click);
            // 
            // darkTextBox1
            // 
            this.darkTextBox1.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(69)))), ((int)(((byte)(73)))), ((int)(((byte)(74)))));
            this.darkTextBox1.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.darkTextBox1.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkTextBox1.Location = new System.Drawing.Point(3, 3);
            this.darkTextBox1.Name = "darkTextBox1";
            this.darkTextBox1.Size = new System.Drawing.Size(225, 21);
            this.darkTextBox1.TabIndex = 0;
            // 
            // panel2
            // 
            this.panel2.Controls.Add(this.darkLabel5);
            this.panel2.Controls.Add(this.darkLabel6);
            this.panel2.Controls.Add(this.darkLabel4);
            this.panel2.Controls.Add(this.darkLabel3);
            this.panel2.Controls.Add(this.darkLabel2);
            this.panel2.Controls.Add(this.darkLabel1);
            this.panel2.Location = new System.Drawing.Point(10, 8);
            this.panel2.Name = "panel2";
            this.panel2.Size = new System.Drawing.Size(112, 300);
            this.panel2.TabIndex = 0;
            // 
            // darkLabel3
            // 
            this.darkLabel3.AutoSize = true;
            this.darkLabel3.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel3.Location = new System.Drawing.Point(5, 75);
            this.darkLabel3.Name = "darkLabel3";
            this.darkLabel3.Size = new System.Drawing.Size(65, 12);
            this.darkLabel3.TabIndex = 2;
            this.darkLabel3.Text = "타일 높이 :";
            // 
            // darkLabel2
            // 
            this.darkLabel2.AutoSize = true;
            this.darkLabel2.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel2.Location = new System.Drawing.Point(5, 42);
            this.darkLabel2.Name = "darkLabel2";
            this.darkLabel2.Size = new System.Drawing.Size(53, 12);
            this.darkLabel2.TabIndex = 1;
            this.darkLabel2.Text = "타일 폭 :";
            // 
            // darkLabel1
            // 
            this.darkLabel1.AutoSize = true;
            this.darkLabel1.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel1.Location = new System.Drawing.Point(5, 8);
            this.darkLabel1.Name = "darkLabel1";
            this.darkLabel1.Size = new System.Drawing.Size(89, 12);
            this.darkLabel1.TabIndex = 0;
            this.darkLabel1.Text = "프로젝트 경로 :";
            // 
            // darkLabel4
            // 
            this.darkLabel4.AutoSize = true;
            this.darkLabel4.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel4.Location = new System.Drawing.Point(5, 110);
            this.darkLabel4.Name = "darkLabel4";
            this.darkLabel4.Size = new System.Drawing.Size(49, 12);
            this.darkLabel4.TabIndex = 3;
            this.darkLabel4.Text = "타일셋 :";
            // 
            // openFileDialog1
            // 
            this.openFileDialog1.FileName = "openFileDialog1";
            this.openFileDialog1.Filter = "*.png|*.*";
            // 
            // darkTilesetOpenButton
            // 
            this.darkTilesetOpenButton.Location = new System.Drawing.Point(232, 106);
            this.darkTilesetOpenButton.Name = "darkTilesetOpenButton";
            this.darkTilesetOpenButton.Padding = new System.Windows.Forms.Padding(5);
            this.darkTilesetOpenButton.Size = new System.Drawing.Size(54, 23);
            this.darkTilesetOpenButton.TabIndex = 5;
            this.darkTilesetOpenButton.Text = "Open";
            this.darkTilesetOpenButton.Click += new System.EventHandler(this.darkTilesetOpenButton_Click);
            // 
            // darkTileset
            // 
            this.darkTileset.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(69)))), ((int)(((byte)(73)))), ((int)(((byte)(74)))));
            this.darkTileset.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.darkTileset.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkTileset.Location = new System.Drawing.Point(4, 106);
            this.darkTileset.Name = "darkTileset";
            this.darkTileset.Size = new System.Drawing.Size(225, 21);
            this.darkTileset.TabIndex = 4;
            // 
            // darkLabel5
            // 
            this.darkLabel5.AutoSize = true;
            this.darkLabel5.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel5.Location = new System.Drawing.Point(5, 174);
            this.darkLabel5.Name = "darkLabel5";
            this.darkLabel5.Size = new System.Drawing.Size(93, 12);
            this.darkLabel5.TabIndex = 5;
            this.darkLabel5.Text = "맵의 세로 크기 :";
            // 
            // darkLabel6
            // 
            this.darkLabel6.AutoSize = true;
            this.darkLabel6.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel6.Location = new System.Drawing.Point(5, 141);
            this.darkLabel6.Name = "darkLabel6";
            this.darkLabel6.Size = new System.Drawing.Size(93, 12);
            this.darkLabel6.TabIndex = 4;
            this.darkLabel6.Text = "맵의 가로 크기 :";
            // 
            // darkMapHeight
            // 
            this.darkMapHeight.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(69)))), ((int)(((byte)(73)))), ((int)(((byte)(74)))));
            this.darkMapHeight.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.darkMapHeight.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkMapHeight.Location = new System.Drawing.Point(5, 173);
            this.darkMapHeight.Name = "darkMapHeight";
            this.darkMapHeight.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.darkMapHeight.Size = new System.Drawing.Size(282, 21);
            this.darkMapHeight.TabIndex = 7;
            this.darkMapHeight.Text = "13";
            this.darkMapHeight.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.darkMapHeight.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.darkTileWidth_KeyPress);
            // 
            // darkMapWidth
            // 
            this.darkMapWidth.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(69)))), ((int)(((byte)(73)))), ((int)(((byte)(74)))));
            this.darkMapWidth.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.darkMapWidth.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkMapWidth.Location = new System.Drawing.Point(4, 139);
            this.darkMapWidth.Name = "darkMapWidth";
            this.darkMapWidth.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.darkMapWidth.Size = new System.Drawing.Size(282, 21);
            this.darkMapWidth.TabIndex = 6;
            this.darkMapWidth.Text = "17";
            this.darkMapWidth.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.darkMapWidth.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.darkTileWidth_KeyPress);
            // 
            // ProjectEditor
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(437, 363);
            this.Controls.Add(this.panel1);
            this.Name = "ProjectEditor";
            this.Text = "프로젝트 에디터";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.ProjectEditor_FormClosing);
            this.Load += new System.EventHandler(this.ProjectEditor_Load);
            this.panel1.ResumeLayout(false);
            this.panel4.ResumeLayout(false);
            this.panel3.ResumeLayout(false);
            this.panel3.PerformLayout();
            this.panel2.ResumeLayout(false);
            this.panel2.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.Panel panel1;
        private System.Windows.Forms.Panel panel4;
        private System.Windows.Forms.Panel panel3;
        private System.Windows.Forms.Panel panel2;
        private DarkUI.Controls.DarkTextBox darkTextBox1;
        private DarkUI.Controls.DarkLabel darkLabel1;
        private DarkUI.Controls.DarkButton darkButton1;
        private System.Windows.Forms.FolderBrowserDialog folderBrowserDialog1;
        private DarkUI.Controls.DarkTextBox darkTileWidth;
        private DarkUI.Controls.DarkLabel darkLabel2;
        private DarkUI.Controls.DarkTextBox darkTileHeight;
        private DarkUI.Controls.DarkLabel darkLabel3;
        private DarkUI.Controls.DarkButton darkButtonOk;
        private DarkUI.Controls.DarkButton darkTilesetOpenButton;
        private DarkUI.Controls.DarkTextBox darkTileset;
        private DarkUI.Controls.DarkLabel darkLabel4;
        private System.Windows.Forms.OpenFileDialog openFileDialog1;
        private DarkUI.Controls.DarkTextBox darkMapHeight;
        private DarkUI.Controls.DarkTextBox darkMapWidth;
        private DarkUI.Controls.DarkLabel darkLabel5;
        private DarkUI.Controls.DarkLabel darkLabel6;
    }
}