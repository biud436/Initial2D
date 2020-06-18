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

using Microsoft.DirectX;
using Microsoft.DirectX.Direct3D;

namespace Editor
{
    public partial class TilemapControl : UserControl
    {
        private Image tileset;
        private bool isMouseLB;
        private Point mouse;
        private int lastTileId;
        private Rectangle tileCursor;
        private bool isReady;
        private TileCursor cursor;

        private Rectangle prevCursor;
        private Point prevMouse;

        private IRenderCommand RenderCommand;

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
            tileCursor = new Rectangle(0, 0, DataManager.Instance.TileWidth, DataManager.Instance.TileHeight);
            lastTileId = 0;
            Size = new Size(638, 503);

            SetStyle(ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.UserPaint, false);

            SetStyle(ControlStyles.OptimizedDoubleBuffer, true);

            ResizeRedraw = true;
            DoubleBuffered = true;

            RenderCommand = new TilemapRenderCommand(new GridRenderCommand());

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
            cursor = new TileCursor();

            this.Controls.Add(cursor);
        }

        public void Connect()
        {
            Init();
            InitWithCursor();

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
            Draw();
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
                this.tileCursor = value;
            }

            get
            {
                return this.tileCursor;
            }
        }

        /// <summary>
        /// 타일맵 렌더링 함수입니다.
        /// 묘화 시 더블 버퍼링을 사용하여 깜빡임을 없앱니다.
        /// </summary>
        public void Draw()
        {
            var g = CreateGraphics();

            BufferedGraphicsContext currentContext;
            BufferedGraphics myBuffer;

            currentContext = BufferedGraphicsManager.Current;

            myBuffer = currentContext.Allocate(g, this.DisplayRectangle);

            myBuffer.Graphics.Clear(this.BackColor);

            InitWithTilemap(myBuffer.Graphics);
            cursor.Render(myBuffer.Graphics);

            myBuffer.Render(g);

            myBuffer.Graphics.Dispose();
            g.Dispose();
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);

            DrawTile(e);
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

            DrawTile(e);
        }

        /// <summary>
        /// 타일 ID를 설정합니다.
        /// </summary>
        /// <param name="value"></param>
        public void SetLastTileId(int value)
        {
            lastTileId = value;
        }

        /// <summary>
        /// 마지막 타일 ID를 반환합니다.
        /// </summary>
        /// <returns></returns>
        public int GetLastTileId()
        {
            return lastTileId;
        }

        /// <summary>
        /// 타일 커서의 위치를 설정합니다.
        /// </summary>
        /// <param name="x"></param>
        /// <param name="y"></param>
        public void SetCursorPosition(int x, int y)
        {
            if (cursor == null)
            {
                return;
            }

            cursor.Location = new Point(x, y);
        }

        /// <summary>
        /// 타일맵 범위 안에 커서가 있는지 확인합니다.
        /// </summary>
        /// <param name="targetX"></param>
        /// <param name="targetY"></param>
        /// <returns></returns>
        public bool IsValidBoundary(int targetX, int targetY)
        {
            var db = DataManager.Instance;
            var mapWidth = db.MapWidth;
            var mapHeight = db.MapHeight;

            return targetY >= 0 && targetY < mapHeight && targetX >= 0 && targetX < mapWidth;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="e"></param>
        private void DrawTile(MouseEventArgs e)
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
                var cursorCol = tileCursor.X / tw;
                var cursorRow = (tileCursor.Y / th);
                int targetX = nx / tw;
                int targetY = ny / th;

                SetLastTileId((cursorRow * mapCols) + cursorCol);

                // 타일이 맵의 크기를 넘어서 그려지는 것을 방지합니다.
                if (IsValidBoundary(targetX, targetY))
                {
                    DataManager.Instance.Layer1[targetY * mapWidth + targetX] = GetLastTileId();

                    SetCursorPosition(nx, ny);

                    Draw();
                }
            }
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="g"></param>
        private void InitWithTilemap(Graphics g)
        {
            RenderCommand.Execute(g, new object[] 
            {
                mouse.X,
                mouse.Y,
                tileset,
            });
        }

    }
}
