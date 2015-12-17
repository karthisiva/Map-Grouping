//
//  ShopViewController.swift
//  Map-clustering
//
//  Created by Macbook Pro  on 12/16/15.
//  Copyright © 2015 Macbook Pro . All rights reserved.
//
struct Shop {
    let name: String
    let latitude: Double
    let longitude: Double
}
import UIKit
import MapKit


class ShopViewController: UIViewController {

    var shops: [Shop] = []
    
    override func viewDidLoad() {
        
        // add a mapview
        let mv = MKMapView()
        view.addSubview(mv)
//        mv.frame=CGRectMake(0, 0, 375, 580);
        mv.frame=(frame: UIScreen.mainScreen().bounds)
        // add layout constraints maximizing the mapview in the parent view
        mv.translatesAutoresizingMaskIntoConstraints = false
//        for a in [{ (v: UIView) in v.topAnchor }, { if #available(iOS 9.0, *) {
//            $0.bottomAnchor
//        } else {
//            // Fallback on earlier versions
//        } }, { $0.leftAnchor }, { $0.rightAnchor }] {
//            a(mv).constraintEqualToAnchor(a(view)).active = true
//        }
        
        // construct and add annotations for our model
        for shop in shops {
            let p = constructAnnotationForTitle(shop.name, coordinate: CLLocationCoordinate2D(latitude: shop.latitude, longitude: shop.longitude))
            mv.addAnnotation(p)
        }
//        let location=CLLocation();
//        
//        let p = constructAnnotationForTitle("karthi", coordinate: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
//        mv.addAnnotation(p)
        // at this point we may have annotations contesting a location
        
        // construct new annotations
        let newAnnotations = ContestedAnnotationTool.annotationsByDistributingAnnotations(mv.annotations) { (oldAnnotation:MKAnnotation, newCoordinate:CLLocationCoordinate2D) in
            self.constructAnnotationForTitle(oldAnnotation.title!, coordinate: newCoordinate)
        }
        
        // replace annotations
        mv.removeAnnotations(mv.annotations)
        mv.addAnnotations(newAnnotations)
        
        // zoom to annotations
        mv.showAnnotations(mv.annotations, animated: true)
        
    }
    
    // Constructs an MKAnnotation, in this demo just a point
    private func constructAnnotationForTitle(title: String?, coordinate: CLLocationCoordinate2D) -> MKAnnotation {
        let p = MKPointAnnotation()
        p.coordinate = coordinate
        p.title = title
        return p
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
public struct ContestedAnnotationTool {
    
    private static let radiusOfEarth = Double(6378100)
    
    public typealias annotationRelocator = ((oldAnnotation:MKAnnotation, newCoordinate:CLLocationCoordinate2D) -> (MKAnnotation))
    
    public static func annotationsByDistributingAnnotations(annotations: [MKAnnotation], constructNewAnnotationWithClosure ctor: annotationRelocator) -> [MKAnnotation] {
        
        // 1. group the annotations by coordinate
        
        let coordinateToAnnotations = groupAnnotationsByCoordinate(annotations)
        
        // 2. go through the groups and redistribute
        
        var newAnnotations = [MKAnnotation]()
        
        for (_, annotationsAtCoordinate) in coordinateToAnnotations {
            
            let newAnnotationsAtCoordinate = ContestedAnnotationTool.annotationsByDistributingAnnotationsContestingACoordinate(annotationsAtCoordinate, constructNewAnnotationWithClosure: ctor)
            
            newAnnotations.appendContentsOf(newAnnotationsAtCoordinate)
        }
        
        return newAnnotations
    }
    
    private static func groupAnnotationsByCoordinate(annotations: [MKAnnotation]) -> [CLLocationCoordinate2D: [MKAnnotation]] {
        var coordinateToAnnotations = [CLLocationCoordinate2D: [MKAnnotation]]()
        for annotation in annotations {
            let coordinate = annotation.coordinate
            let annotationsAtCoordinate = coordinateToAnnotations[coordinate] ?? [MKAnnotation]()
            coordinateToAnnotations[coordinate] = annotationsAtCoordinate + [annotation]
        }
        return coordinateToAnnotations
    }
    
    private static func annotationsByDistributingAnnotationsContestingACoordinate(annotations: [MKAnnotation], constructNewAnnotationWithClosure ctor: annotationRelocator) -> [MKAnnotation] {
        
        var newAnnotations = [MKAnnotation]()
        
        let contestedCoordinates = annotations.map{ $0.coordinate }
        
        let newCoordinates = coordinatesByDistributingCoordinates(contestedCoordinates)
        
        for (i, annotation) in annotations.enumerate() {
            
            let newCoordinate = newCoordinates[i]
            
            let newAnnotation = ctor(oldAnnotation: annotation, newCoordinate: newCoordinate)
            
            newAnnotations.append(newAnnotation)
        }
        
        return newAnnotations
    }
    
    private static func coordinatesByDistributingCoordinates(coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        
        if coordinates.count == 1 {
            return coordinates
        }
        
        var result = [CLLocationCoordinate2D]()
        
        let distanceFromContestedLocation: Double = 3.0 * Double(coordinates.count) / 2.0
        let radiansBetweenAnnotations = (M_PI * 2) / Double(coordinates.count)
        
        for (i, coordinate) in coordinates.enumerate() {
            
            let bearing = radiansBetweenAnnotations * Double(i)
            let newCoordinate = calculateCoordinateFromCoordinate(coordinate, onBearingInRadians: bearing, atDistanceInMetres: distanceFromContestedLocation)
            
            result.append(newCoordinate)
        }
        
        return result
    }
    
    private static func calculateCoordinateFromCoordinate(coordinate: CLLocationCoordinate2D, onBearingInRadians bearing: Double, atDistanceInMetres distance: Double) -> CLLocationCoordinate2D {
        
        let coordinateLatitudeInRadians = coordinate.latitude * M_PI / 180;
        let coordinateLongitudeInRadians = coordinate.longitude * M_PI / 180;
        
        let distanceComparedToEarth = distance / radiusOfEarth;
        
        let resultLatitudeInRadians = asin(sin(coordinateLatitudeInRadians) * cos(distanceComparedToEarth) + cos(coordinateLatitudeInRadians) * sin(distanceComparedToEarth) * cos(bearing));
        let resultLongitudeInRadians = coordinateLongitudeInRadians + atan2(sin(bearing) * sin(distanceComparedToEarth) * cos(coordinateLatitudeInRadians), cos(distanceComparedToEarth) - sin(coordinateLatitudeInRadians) * sin(resultLatitudeInRadians));
        
        let latitude = resultLatitudeInRadians * 180 / M_PI;
        let longitude = resultLongitudeInRadians * 180 / M_PI;
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// To use CLLocationCoordinate2D as a key in a dictionary, it needs to comply with the Hashable protocol
extension CLLocationCoordinate2D: Hashable {
    public var hashValue: Int {
        get {
            return (latitude.hashValue&*397) &+ longitude.hashValue;
        }
    }
}

// To be Hashable, you need to be Equatable too
public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}
