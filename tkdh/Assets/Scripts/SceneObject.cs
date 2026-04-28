using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace tkdh
{
    public class SceneObject : MonoBehaviour
    {
        public virtual HitData Intersect(MyRay ray)
        {
            HitData hitData = new HitData();
            return hitData;
        }
    }

    public class HitData
    {
        public Color color;
        public float distance;
        public bool isIntersect;

        public Vector3 normal;
        public Vector3 intersectionPoint;
    }

}

