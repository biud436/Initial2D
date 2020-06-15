using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using DarkUI.Forms;

namespace Editor
{
    public class Tilemap
    {

        private int _width;
        private int _height;
        private int _layerId;

        /// <summary>
        /// 생성자
        /// </summary>
        public Tilemap() {
            this._width = DataManager.Instance.MapWidth;
            this._height = DataManager.Instance.MapHeight;
        }

        /// <summary>
        /// 생성자
        /// </summary>
        /// <param name="width">타일맵의 폭</param>
        /// <param name="height">타일맵의 높이</param>
        public Tilemap(int width, int height)
        {
            this._width = width;
            this._height = height;
        }

        /// <summary>
        /// 렌더링
        /// </summary>
        public void Render()
        {

        }

        public int Width
        {
            get { return this._width; }
            set { this._width = value; }
        }

        public int Height
        {
            get { return this._height; }
            set { this._height = value; }
        }

    }
}
