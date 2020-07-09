using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Runtime;

namespace Editor.Core
{
    public sealed class Layer : ICloneable, IDisposable
    {
        public static int WIDTH = 17;
        public static int HEIGHT = 13;
        public static int MAX_LAYERS = 3;

        private List<List<int>> mLayers { get; set; }

        private int mWidth;
        private int mHeight;
        private Guid mId;

        public Layer()
        {
            Init(Layer.WIDTH, Layer.HEIGHT);
        }

        #region 복사, 문자열화, 메모리 해제 오버라이드
        public object Clone()
        {
            return this.MemberwiseClone();
        }

        public override string ToString()
        {
            return $"Layer {mId} Count : {mLayers.Count}";
        }

        public void Dispose()
        {

        }
        #endregion

        private void Remove()
        {
            mLayers.Clear();
        }

        public Layer(int width, int height)
        {
            try
            {
                Init(width, height);
            }
            catch (Exception ex)
            {
                Debug.Fail(ex.Message);
            }
        }

        /// <summary>
        /// Sets the map data for certain layerId between 0 and 2.
        /// </summary>
        /// <param name="x"></param>
        /// <param name="y"></param>
        /// <param name="data"></param>
        /// <param name="layerId"></param>
        public void SetData(int x, int y, int data, int layerId)
        {
            if(layerId < 0)
            {
                layerId = 0;
            }

            if(layerId > (MAX_LAYERS - 1))
            {
                layerId = MAX_LAYERS - 1;
            }

            if(data < 0)
            {
                data = 0;
            }

            if(data >= 255)
            {
                data = 255;
            }

            mLayers[layerId][y * mWidth + x] = data;
        }

        public void Init(int width, int height)
        {
            mWidth = width;
            mHeight = height;
            mId = Guid.NewGuid();

            for (int i = 0; i < Layer.MAX_LAYERS; i++)
            {
                mLayers.Add(LayerCreator.Instance.Create(width, height));
            }
        }
    }
}
