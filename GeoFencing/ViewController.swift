//
//  ViewController.swift
//  SomeApp
//
//  Created by Mustafa Khalil on 1/7/20.
//  Copyright © 2020 Mustafa Khalil. All rights reserved.
//

import UIKit
import MapKit

func GenerateLocations() -> [Distance] {
    var locations: [Distance] = []
    for i in 0...100 {
        let long = Double.random(in: 122.004032...122.057419)
        let lat = Double.random(in: 37.308548...37.366830)
        locations.append(Distance(coords: CLLocation(latitude: lat, longitude: -long), distance: .infinity, id: "\(i)"))
    }
    return locations
}

struct Distance: Comparable {
    var coords: CLLocation
    var distance: Double
    let id: String
    
    static func >(lhs: Distance, rhs: Distance) -> Bool {
        lhs.distance > rhs.distance
    }
    static func <(lhs: Distance, rhs: Distance) -> Bool {
        lhs.distance < rhs.distance
    }
}

class ViewController: UIViewController, TrackerDelegate, MKMapViewDelegate {
    func updateUser(location: CLLocation) {
        map.centerCoordinate = location.coordinate
        print("Update User location")
        var shouldTrack: [Distance] = []
        Tracker.shared.stopTracking()
        for i in locations {
            let distance = location.distance(from: i.coords)
            shouldTrack.append(Distance(coords: i.coords, distance: distance, id: i.id))
        }
        shouldTrack.sort { (d1, d2) -> Bool in
            return d1 < d2
        }
        for i in 0..<20 {
            Tracker.shared.trackLocation(location: shouldTrack[i])
        }
        print(shouldTrack[0].distance)
        print("Monitoring")
    }

    var locations = GenerateLocations()
    
    lazy var map: MKMapView = {
        var m = MKMapView()
        m.translatesAutoresizingMaskIntoConstraints = false
        m.userTrackingMode = .follow
        m.delegate = self
        return m
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.addSubview(map)
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        var annot: [MKPointAnnotation] = []
        for location in locations {
            let london = MKPointAnnotation()
            london.title = location.id
            london.coordinate = location.coords.coordinate
            annot.append(london)
        }
        map.addAnnotations(annot)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Tracker.shared.prepare(delegate: self)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil }
        let identifier = "Annotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = true
        } else {
            annotationView!.annotation = annotation
        }

        return annotationView
    }
    
}

protocol TrackerDelegate: NSObjectProtocol {
    func updateUser(location: CLLocation)
}

class Tracker: NSObject, CLLocationManagerDelegate {
    var location = CLLocationManager()
    var startTime: CFAbsoluteTime?
    weak var delegate: TrackerDelegate?
    
    static var shared = Tracker()
    
    func prepare(delegate: TrackerDelegate) {
        location.allowsBackgroundLocationUpdates = true
        location.startMonitoringSignificantLocationChanges()
        location.delegate = self
        self.delegate = delegate
        requestAuth(str: "Prepare")
    }
    
    func stopTracking() {
        location.monitoredRegions.forEach { (r) in
            location.stopMonitoring(for: r)
        }
    }
    
    fileprivate func requestAuth(str: String) {
        print("from: \(str)")
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways:
            print("Always \(str)")
        case .authorizedWhenInUse:
            DispatchQueue.main.async { [weak self] in
                self?.location.requestAlwaysAuthorization()
            }
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Denied")
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(locations)
        guard let loc = locations.first else { return }
        delegate?.updateUser(location: loc)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        requestAuth(str: "status")
    }
    
    func trackLocation(location coords: Distance) {
        let region = CLCircularRegion(center: coords.coords.coordinate, radius: 50, identifier: coords.id)
        location.startMonitoring(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        startTime = CFAbsoluteTimeGetCurrent()
        print("Entering region: \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let t = startTime {
            let endTime = CFAbsoluteTimeGetCurrent() - t
            print(endTime)
        }
        print("Exiting region: \(region.identifier)")
    }
}
