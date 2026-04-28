using System.Collections;
using System.Collections.Generic;
using tkdh;
using UnityEngine;

namespace tkdh
{
    public class MySphere : SceneObject
    {
        public Vector3 center;
        public float radius;
        public Color color;

        private void OnDrawGizmos()
        {
            center = transform.position;
            Gizmos.color = color;
            Gizmos.DrawSphere(center, radius);
        }

        public override HitData Intersect(MyRay ray)
        {
            HitData hitData = new HitData();
            //check if object is in front of camera
            Vector3 rsVec = center - ray.origin;
            float rsDotDir = Vector3.Dot(rsVec, ray.direction);
            if (rsDotDir < 0)
            {
                return null;
            }

            float a = ray.direction.sqrMagnitude;
            float b = -2 * rsDotDir;
            float c = rsVec.sqrMagnitude - radius * radius;

            //delta = b*b - 4ac
            float delta = b * b - 4 * a * c;

            if (delta < 0)
            {
                return null;
            }

            hitData.distance = (-b - Mathf.Sqrt(delta)) / (2 * a);
            hitData.color = color;
            hitData.isIntersect = true;

            return hitData;
        }
    }
}

