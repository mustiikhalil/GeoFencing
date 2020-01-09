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
        locations.append(Distance(coords: CLLocation(latitude: lat, longitude: -long), id: "\(i)"))
    }
    return locations
}

struct Distance: Comparable {
    var coords: CLLocation
    let id: String
    
    static func >(lhs: Distance, rhs: Distance) -> Bool {
        lhs.id > rhs.id
    }
    static func <(lhs: Distance, rhs: Distance) -> Bool {
        lhs.id < rhs.id
    }
}

class ViewController: UIViewController, TrackerDelegate, MKMapViewDelegate {
    func updateUser(location: CLLocation) {
        map.centerCoordinate = location.coordinate
        print("Update User location")
        Tracker.shared.track(locations, aroundUsers: location)
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
    private var radius = 200
    
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
    
    func track(_ locations: [Distance], aroundUsers userLocation: CLLocation) {
        
        let set = Tracker.shared.stopTracking(outside: userLocation)
        
        var shouldTrack = locations
        shouldTrack.sort { (d1, d2) -> Bool in
            return userLocation.distance(from: d1.coords) < userLocation.distance(from: d2.coords)
        }
        
        var tracking: [String] = []
        for i in 0..<20 {
            if !set.contains(where: { $0.identifier == shouldTrack[i].id }) {
                tracking.append(shouldTrack[i].id)
                Tracker.shared.trackLocation(location: shouldTrack[i])
            }
        }
        print("Start Monitoring \(tracking) without count: \(tracking.count)")
    }
    
    func stopTracking(outside currentLocation: CLLocation) -> Set<CLRegion> {
        var tracking: [String] = []
        var currentlyTracking = Set<CLRegion>()
        location.monitoredRegions.forEach { (r) in
            if let monitored = r as? CLCircularRegion, !monitored.contains(currentLocation.coordinate) {
                tracking.append(r.identifier)
                location.stopMonitoring(for: r)
            } else {
                currentlyTracking.insert(r)
            }
        }
        
        print("Stop Monitoring \(tracking) without count: \(tracking.count)")
        return currentlyTracking
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
        let region = CLCircularRegion(center: coords.coords.coordinate, radius: 200, identifier: coords.id)
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
