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
            this.panel2 = new System.Windows.Forms.Panel();
            this.panel3 = new System.Windows.Forms.Panel();
            this.panel4 = new System.Windows.Forms.Panel();
            this.darkLabel1 = new DarkUI.Controls.DarkLabel();
            this.darkTextBox1 = new DarkUI.Controls.DarkTextBox();
            this.darkButton1 = new DarkUI.Controls.DarkButton();
            this.folderBrowserDialog1 = new System.Windows.Forms.FolderBrowserDialog();
            this.darkLabel2 = new DarkUI.Controls.DarkLabel();
            this.darkTileWidth = new DarkUI.Controls.DarkTextBox();
            this.darkLabel3 = new DarkUI.Controls.DarkLabel();
            this.darkTileHeight = new DarkUI.Controls.DarkTextBox();
            this.darkButtonOk = new DarkUI.Controls.DarkButton();
            this.panel1.SuspendLayout();
            this.panel2.SuspendLayout();
            this.panel3.SuspendLayout();
            this.panel4.SuspendLayout();
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
            this.panel1.Size = new System.Drawing.Size(437, 247);
            this.panel1.TabIndex = 0;
            // 
            // panel2
            // 
            this.panel2.Controls.Add(this.darkLabel3);
            this.panel2.Controls.Add(this.darkLabel2);
            this.panel2.Controls.Add(this.darkLabel1);
            this.panel2.Location = new System.Drawing.Point(10, 8);
            this.panel2.Name = "panel2";
            this.panel2.Size = new System.Drawing.Size(112, 183);
            this.panel2.TabIndex = 0;
            // 
            // panel3
            // 
            this.panel3.Controls.Add(this.darkTileHeight);
            this.panel3.Controls.Add(this.darkTileWidth);
            this.panel3.Controls.Add(this.darkButton1);
            this.panel3.Controls.Add(this.darkTextBox1);
            this.panel3.Location = new System.Drawing.Point(128, 8);
            this.panel3.Name = "panel3";
            this.panel3.Size = new System.Drawing.Size(295, 182);
            this.panel3.TabIndex = 1;
            // 
            // panel4
            // 
            this.panel4.Controls.Add(this.darkButtonOk);
            this.panel4.Dock = System.Windows.Forms.DockStyle.Bottom;
            this.panel4.Location = new System.Drawing.Point(0, 198);
            this.panel4.Name = "panel4";
            this.panel4.Size = new System.Drawing.Size(437, 49);
            this.panel4.TabIndex = 2;
            // 
            // darkLabel1
            // 
            this.darkLabel1.AutoSize = true;
            this.darkLabel1.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel1.Location = new System.Drawing.Point(5, 8);
            this.darkLabel1.Name = "darkLabel1";
            this.darkLabel1.Size = new System.Drawing.Size(81, 12);
            this.darkLabel1.TabIndex = 0;
            this.darkLabel1.Text = "Project Root :";
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
            // darkLabel2
            // 
            this.darkLabel2.AutoSize = true;
            this.darkLabel2.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel2.Location = new System.Drawing.Point(5, 42);
            this.darkLabel2.Name = "darkLabel2";
            this.darkLabel2.Size = new System.Drawing.Size(68, 12);
            this.darkLabel2.TabIndex = 1;
            this.darkLabel2.Text = "Tile Width :";
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
            // darkLabel3
            // 
            this.darkLabel3.AutoSize = true;
            this.darkLabel3.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(220)))), ((int)(((byte)(220)))), ((int)(((byte)(220)))));
            this.darkLabel3.Location = new System.Drawing.Point(5, 75);
            this.darkLabel3.Name = "darkLabel3";
            this.darkLabel3.Size = new System.Drawing.Size(73, 12);
            this.darkLabel3.TabIndex = 2;
            this.darkLabel3.Text = "Tile Height :";
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
            // ProjectEditor
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(437, 247);
            this.Controls.Add(this.panel1);
            this.Name = "ProjectEditor";
            this.Text = "프로젝트 에디터";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.ProjectEditor_FormClosing);
            this.Load += new System.EventHandler(this.ProjectEditor_Load);
            this.panel1.ResumeLayout(false);
            this.panel2.ResumeLayout(false);
            this.panel2.PerformLayout();
            this.panel3.ResumeLayout(false);
            this.panel3.PerformLayout();
            this.panel4.ResumeLayout(false);
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
    }
}