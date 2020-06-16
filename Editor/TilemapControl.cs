using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using DarkUI.Config;
using System.Diagnostics;
using System.Drawing.Drawing2D;

namespace Editor
{
    public partial class TilemapControl : UserControl
    {
        private Image tileset;
        private bool isMouseLB;
        private Point mouse;
        private int lastTileId;
        private Rectangle tileCurosr;
        private bool isReady;
        private Pen whitePen;
        private Pen blackPen;

        private Rectangle prevCursor;
        private Point prevMouse;

        public TilemapControl()
        {
            InitializeComponent();
        }

        /// <summary>
        /// 
        /// </summary>
        private void Init()
        {
            isMouseLB = false;
            isReady = false;
            mouse = new Point(0, 0);
            prevMouse = new Point(0, 0);
            prevCursor = new Rectangle(0, 0, 0, 0);
            tileCurosr = new Rectangle(0, 0, DataManager.Instance.TileWidth, DataManager.Instance.TileHeight);
            lastTileId = 0;
            Size = new Size(638, 503);

            this.Disposed += TilemapControl_Disposed;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void TilemapControl_Disposed(object sender, EventArgs e)
        {
            
        }

        private void InitWithCursor()
        {
            //cursor = new Cursor();
            //this.Controls.Add(cursor);
        }

        public void Connect()
        {
            Init();
            InitWithCursor();

            whitePen = new Pen(Color.White, 2);
            blackPen = new Pen(Color.Black, 1);
            whitePen.Alignment = PenAlignment.Inset;

            var imageName = DataManager.Instance.TilesetImage;

            if(String.IsNullOrEmpty(imageName))
            {
                imageName = @"E:\VS2015\Projects\Initial2D\resources\tiles\tileset16-8x13.png";
            }

            tileset = Image.FromFile(imageName);
        }

        public void Ready()
        {
            isReady = true;
        }

        public void Flush()
        {
            isReady = false;
        }

        /// <summary>
        /// 
        /// </summary>
        public Image TilesetImage
        {
            set
            {
                tileset = value;
            }

            get
            {
                return tileset;
            }
        }

        /// <summary>
        /// 
        /// </summary>
        public Rectangle TileCurosr
        {
            set
            {
                this.tileCurosr = value;
            }

            get
            {
                return this.tileCurosr;
            }
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);

            var g = e.Graphics;

            if (!isReady)
            {
                isReady = true;
                InitWithTilemap(g);
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

            Image tilesetImage = tileset;
            Rectangle srcRect = tileCurosr;
            Rectangle destRect = new Rectangle(mx, my, tw, th);

            // 타일셋 이미지에서 특정 타일을 그립니다.
            g.DrawImage(tilesetImage, mx, my, srcRect, GraphicsUnit.Pixel);

            // 맵 그리드를 그립니다.
            DrawGrid(g);

        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);

            DrawTilemap(e);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);

            if (e.Button == MouseButtons.Left)
            {
                isMouseLB = false;
            }
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);

            DrawTilemap(e);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        protected override void OnPaintBackground(PaintEventArgs e)
        {
            base.OnPaintBackground(e);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        private void DrawTilemap(MouseEventArgs e)
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
                if (tileset == null)
                {
                    return;
                }

                var mapCols = tileset.Width / tw;
                var mapRows = tileset.Height / th;
                var cursorCol = tileCurosr.X / tw;
                var cursorRow = (tileCurosr.Y / th);

                lastTileId = (cursorRow * mapCols) + cursorCol;
                int targetX = nx / tw;
                int targetY = ny / th;

                // 타일이 맵의 크기를 넘어서 그려지는 것을 방지합니다.
                if (targetY >= 0 && targetY < mapHeight && targetX >= 0 && targetX < mapWidth)
                {
                    DataManager.Instance.Layer1[targetY * mapWidth + targetX] = lastTileId;

                    this.Invalidate(new Rectangle(nx, ny, tw, th), true);
                }

            }
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="g"></param>
        private void InitWithTilemap(Graphics g)
        {
            int mapWidth = DataManager.Instance.MapWidth;
            int mapHeight = DataManager.Instance.MapHeight;

            var mx = mouse.X;
            var my = mouse.Y;
            var tw = DataManager.Instance.TileWidth;
            var th = DataManager.Instance.TileHeight;

            Image tilesetImage = tileset;

            var mapCols = tileset.Width / tw;
            var mapRows = tileset.Height / th;

            for (int y = 0; y < mapHeight; y++)
            {
                for (int x = 0; x < mapWidth; x++)
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

            var mx = mouse.X;
            var my = mouse.Y;
            var tw = db.TileWidth;
            var th = db.TileHeight;

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
    }
}
