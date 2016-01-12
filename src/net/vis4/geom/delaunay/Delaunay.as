﻿package net.vis4.geom.delaunay 
{
	import flash.geom.Point;
	
	/**
	 * ...
	 * @author gka
	 */
	public class Delaunay 
	{
		public static const EPSILON:Number = 0.000001;

		/*
		Return TRUE if a point (xp,yp) is inside the circumcircle made up
		of the points (x1,y1), (x2,y2), (x3,y3)
		The circumcircle centre is returned in (xc,yc) and the radius r
		NOTE: A point on the edge is inside the circumcircle
		*/
		public static function CircumCircle(xp:Number, yp:Number, x1:Number, y1:Number, x2:Number, y2:Number, x3:Number, y3:Number, circle:XYZ):Boolean 
		{
			var m1:Number, m2:Number, mx1:Number, mx2:Number, my1:Number, my2:Number;
			var dx:Number, dy:Number, rsqr:Number, drsqr:Number;
			var xc:Number, yc:Number, r:Number;
			
			/* Check for coincident points */
			
			if ( Math.abs(y1-y2) < EPSILON && Math.abs(y2-y3) < EPSILON )
			{
				//trace("CircumCircle: Points are coincident.");
				return false;
			}
			
			if ( Math.abs(y2-y1) < EPSILON )
			{
				m2 = - (x3-x2) / (y3-y2);
				mx2 = (x2 + x3) / 2.0;
				my2 = (y2 + y3) / 2.0;
				xc = (x2 + x1) / 2.0;
				yc = m2 * (xc - mx2) + my2;
			}
			else if ( Math.abs(y3-y2) < EPSILON )
			{
				m1 = - (x2-x1) / (y2-y1);
				mx1 = (x1 + x2) / 2.0;
				my1 = (y1 + y2) / 2.0;
				xc = (x3 + x2) / 2.0;
				yc = m1 * (xc - mx1) + my1;	
			}
			else
			{
				m1 = - (x2-x1) / (y2-y1);
				m2 = - (x3-x2) / (y3-y2);
				mx1 = (x1 + x2) / 2.0;
				mx2 = (x2 + x3) / 2.0;
				my1 = (y1 + y2) / 2.0;
				my2 = (y2 + y3) / 2.0;
				xc = (m1 * mx1 - m2 * mx2 + my2 - my1) / (m1 - m2);
				yc = m1 * (xc - mx1) + my1;
			}
			
			dx = x2 - xc;
			dy = y2 - yc;
			rsqr = dx*dx + dy*dy;
			r = Math.sqrt(rsqr);
			
			dx = xp - xc;
			dy = yp - yc;
			drsqr = dx*dx + dy*dy;
			
			circle.x = xc;
			circle.y = yc;
			circle.z = r;
			
			return ( drsqr <= rsqr ? true : false );
		}

		/*
		Triangulation subroutine
		
		Takes as input, an array of vertices in pxyz
		each vertex should be an instance of the XYZ class
		
		Returned is an array of triangular faces in the array v
		These triangles are arranged in a consistent clockwise order.
		The triangle array 'v' should be malloced to 3 * nv
		The vertex array pxyz must be big enough to hold 3 more points
		The vertex array must be sorted in increasing x values say
		*/
		public static function triangulate(points:Array):Array 
		{			
			var pxyz:Array = [];
			for each (var p:Point in points) { pxyz.push(new XYZ(p.x, p.y, 0));	}
			
			var v:Array=new Array();
			var nv:uint = pxyz.length;
			
			for (var i:int=0; i < (nv*3); i++) {
				v[i] = new Triangle();
			}
			
			// the points must be sorted on the x dimension for the rest to work
			pxyz.sortOn("x", Array.NUMERIC);
			var complete:Array 		= null;
			var edges:Array 		= null;
			var nedge:uint 			= 0;
			var trimax:uint, emax:uint 	= 200;
			var status:uint 			= 0;
			
			var	inside:Boolean;
			var xp:Number, yp:Number, x1:Number, y1:Number, x2:Number, y2:Number, x3:Number, y3:Number, xc:Number, yc:Number, r:Number;
			var xmin:Number, xmax:Number, ymin:Number, ymax:Number, xmid:Number, ymid:Number;
			var dx:Number, dy:Number, dmax:Number;
			
			var	ntri:uint = 0;
			
			/* Allocate memory for the completeness list, flag for each triangle */
			trimax = 4*nv;
			complete = new Array();
			for (var ic:uint=0; ic<trimax; ic++) complete[ic] = false;
			
			/* Allocate memory for the edge list */
			edges = new Array();
			for (var ie:uint=0; ie<emax; ie++) edges[ie] = new Edge();
			
			/*
			Find the maximum and minimum vertex bounds.
			This is to allow calculation of the bounding triangle
			*/
			xmin = pxyz[0].x;
			ymin = pxyz[0].y;
			xmax = xmin;
			ymax = ymin;
			for (i=1;i<nv;i++)
			{
				if (pxyz[i].x < xmin) xmin = pxyz[i].x;
				if (pxyz[i].x > xmax) xmax = pxyz[i].x;
				if (pxyz[i].y < ymin) ymin = pxyz[i].y;
				if (pxyz[i].y > ymax) ymax = pxyz[i].y;
			}
			dx = xmax - xmin;
			dy = ymax - ymin;
			dmax = (dx > dy) ? dx : dy;
			xmid = (xmax + xmin) / 2.0;
			ymid = (ymax + ymin) / 2.0;
			
			/*
				Set up the supertriangle
				This is a triangle which encompasses all the sample points.
				The supertriangle coordinates are added to the end of the
				vertex list. The supertriangle is the first triangle in
				the triangle list.
			*/
			pxyz[nv] = new XYZ();
			pxyz[nv+1] = new XYZ();
			pxyz[nv+2] = new XYZ();
			
			pxyz[nv+0].x = xmid - 2.0 * dmax;
			pxyz[nv+0].y = ymid - dmax;
			pxyz[nv+0].z = 0.0;
			pxyz[nv+1].x = xmid;
			pxyz[nv+1].y = ymid + 2.0 * dmax;
			pxyz[nv+1].z = 0.0;
			pxyz[nv+2].x = xmid + 2.0 * dmax;
			pxyz[nv+2].y = ymid - dmax;
			pxyz[nv+2].z = 0.0;
			
			v[0].p1 = nv;
			v[0].p2 = nv+1;
			v[0].p3 = nv+2;
			complete[0] = false;
			ntri = 1;
			
			/*
				Include each point one at a time into the existing mesh
			*/
			for (i=0;i<nv;i++) {
				
				xp = pxyz[i].x;
				yp = pxyz[i].y;
				nedge = 0;
				
				/*
					Set up the edge buffer.
					If the point (xp,yp) lies inside the circumcircle then the
					three edges of that triangle are added to the edge buffer
					and that triangle is removed.
				*/
				var circle:XYZ = new XYZ();
				for (var j:int=0;j<ntri;j++)
				{
					if (complete[j])
						continue;
					x1 = pxyz[v[j].p1].x;
					y1 = pxyz[v[j].p1].y;
					x2 = pxyz[v[j].p2].x;
					y2 = pxyz[v[j].p2].y;
					x3 = pxyz[v[j].p3].x;
					y3 = pxyz[v[j].p3].y;
					inside = CircumCircle( xp, yp,  x1, y1,  x2, y2,  x3, y3,  circle );
					xc = circle.x; yc = circle.y; r = circle.z;
					if (xc + r < xp) complete[j] = true;
					if (inside)
					{
						/* Check that we haven't exceeded the edge list size */
						if (nedge+3 >= emax)
						{
							trace("crazy if statement");
							emax += 100;
							var edges_n:Array = new Array();
							for (ie=0; ie<emax; ie++) edges_n[ie] = new Edge();
							for (var zfj:uint=0; zfj<edges.length; zfj++) {
								edges_n[zfj] = edges[zfj];
							}
							edges = edges_n;
						}
						edges[nedge+0].p1 = v[j].p1;
						edges[nedge+0].p2 = v[j].p2;
						edges[nedge+1].p1 = v[j].p2;
						edges[nedge+1].p2 = v[j].p3;
						edges[nedge+2].p1 = v[j].p3;
						edges[nedge+2].p2 = v[j].p1;
						nedge += 3;
						v[j].p1 = v[ntri-1].p1;
						v[j].p2 = v[ntri-1].p2;
						v[j].p3 = v[ntri-1].p3;
						complete[j] = complete[ntri-1];
						ntri--;
						j--;
					}
				}
				
				/*
					Tag multiple edges
					Note: if all triangles are specified anticlockwise then all
					interior edges are opposite pointing in direction.
				*/
				for (j=0;j<nedge-1;j++)
				{
					//if ( !(edges[j].p1 < 0 && edges[j].p2 < 0) )
						for (var k:uint= j + 1; k < nedge; k++)
						{
							if ((edges[j].p1 == edges[k].p2) && (edges[j].p2 == edges[k].p1))
							{
								edges[j].p1 = -1;
								edges[j].p2 = -1;
								edges[k].p1 = -1;
								edges[k].p2 = -1;
							}
							/* Shouldn't need the following, see note above */
							if ((edges[j].p1 == edges[k].p1) && (edges[j].p2 == edges[k].p2))
							{
								edges[j].p1 = -1;
								edges[j].p2 = -1;
								edges[k].p1 = -1;
								edges[k].p2 = -1;
							}
						}
				}
				
				/*
					Form new triangles for the current point
					Skipping over any tagged edges.
					All edges are arranged in clockwise order.
				*/
				for (j=0;j<nedge;j++)
				{
					if (edges[j].p1 == -1 || edges[j].p2 == -1)
						continue;
					if (ntri >= trimax) return null;
					v[ntri].p1 = edges[j].p1;
					v[ntri].p2 = edges[j].p2;
					v[ntri].p3 = i;
					complete[ntri] = false;
					ntri++;
				}
			}
			
			/*
				Remove triangles with supertriangle vertices
				These are triangles which have a vertex number greater than nv
			*/
			for (i=0;i<ntri;i++)
			{
				if (v[i].p1 >= nv || v[i].p2 >= nv || v[i].p3 >= nv)
				{
					v[i] = v[ntri-1];
					ntri--;
					i--;
				}
			}
			
			v.length = ntri;
			pxyz.length -= 3;
			
			return v;
		}
		
	}
	
}