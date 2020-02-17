//
//  ViewController.swift
//  OberApp
//
//  Created by Felipe Amorim Bastos on 12/02/20.
//  Copyright © 2020 Felipe Amorim Bastos. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D?
    
    var stepCounter = 0
    var steps: [MKRoute.Step] = []
    var route: MKRoute?
    
    @IBOutlet var txtAdress: UITextField?
    @IBOutlet var mapView: MKMapView?
    @IBOutlet var lblDirection: UILabel?
    
    @IBOutlet var constraintAlignBottomAddressView: NSLayoutConstraint?
    //-----------------------------------------------------------------------
    //    MARK: UIViewController
    //-----------------------------------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        configureLocationService()
        
        if #available(iOS 13.0, *) {
            self.overrideUserInterfaceStyle = .dark
        }
        
        tintPlaceHolder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
    }
    
    //-----------------------------------------------------------------------
    //    MARK: Map Location Delegate
    //-----------------------------------------------------------------------
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let latestLocation = locations.first else {return}
        
        if currentCoordinate == nil {
            zoomToLatestLocation(with: latestLocation.coordinate)
        }
        
        currentCoordinate = latestLocation.coordinate
        
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedAlways || status == .authorizedWhenInUse{
            
            beginLocationUpdates(locationManager: manager)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = UIColor.blue
        return renderer
    }
    
    
    //-----------------------------------------------------------------------
    //    MARK: Custom methods
    //-----------------------------------------------------------------------
    
    @IBAction func showFavorites() {
        
        let addressVC = storyboard?.instantiateViewController(identifier: "AddressesView") as! AddressesViewController
        
        self.present(addressVC, animated: true, completion: nil)
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height
            
            self.constraintAlignBottomAddressView?.constant = keyboardHeight
            
            UIView.animate(withDuration: 0.5,
                         animations: { [weak self] in
                          self?.view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
            
            self.constraintAlignBottomAddressView?.constant = 0
            
            UIView.animate(withDuration: 1,
                         animations: { [weak self] in
                          self?.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    @IBAction func sendCoordinates() {
        
        getCoordinate(addressString: txtAdress?.text ?? "") { (location, error) in
            if let err = error {
                print(err.localizedDescription)
            }else{
                //Add pin to the screen
                let finalLocation = CLLocationCoordinate2DMake(location.latitude, location.longitude)
                
                let annotation = MKPointAnnotation()
                annotation.coordinate = finalLocation
                annotation.title = "\(self.txtAdress?.text ?? "")"
                
                self.mapView?.addAnnotation(annotation)
                self.view.endEditing(true)
                
                let zoomRegion = MKCoordinateRegion(center: finalLocation, latitudinalMeters: 10000, longitudinalMeters: 10000)
                self.mapView?.setRegion(zoomRegion, animated: true)
                
                //Remove previous route
                
                self.mapView?.removeOverlays(self.mapView!.overlays)
                
                //Trace Route
                
                guard let sourceLocation = self.locationManager.location?.coordinate else {return}
                
                let sourcePlacemark = MKPlacemark(coordinate: sourceLocation)
                let destinationPlacemark = MKPlacemark(coordinate: finalLocation)
                
                let sourceItem = MKMapItem(placemark: sourcePlacemark)
                let destinationItem = MKMapItem(placemark: destinationPlacemark)
                
                let routeRequest = MKDirections.Request()
                routeRequest.source = sourceItem
                routeRequest.destination = destinationItem
                routeRequest.transportType = .automobile
                
                let directions = MKDirections(request: routeRequest)
                directions.calculate { (response, error) in
                    if let err = error {
                        print(err.localizedDescription)
                        return
                    }
                    guard let response = response, let route = response.routes.first else {return}
                    
                    self.route = route
                    self.mapView?.addOverlay(route.polyline)
                    self.mapView?.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
                    
                    self.getRouteSteps(route: route)
                }
                
                //Add to Addresses List
                
                let dateFormatter : DateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
                let date = Date()
                let dateString = dateFormatter.string(from: date)
                
                let dic = ["date": dateString,
                           "address": self.txtAdress?.text ?? ""]
                
                if var addressDictionary = UserDefaults.standard.value(forKey: "addresses") as? Array<Dictionary<String,String>> {
                    print("added to favorites")
                    
                    addressDictionary.append(dic)
                    UserDefaults.standard.set(addressDictionary, forKey: "addresses")
                    UserDefaults.standard.synchronize()
                }else{
                    UserDefaults.standard.set([dic], forKey: "addresses")
                }
            }
        }
    }
    
    func getRouteSteps(route: MKRoute) {

        for monitoredRegions in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoring(for: monitoredRegions)
        }

        let steps = self.route?.steps
        self.steps = steps!

        for i in 0..<steps!.count {
            let step = steps![i]
            print(step.instructions)
            print(step.distance)
            
            let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: "\(i)")
            locationManager.startMonitoring(for: region)
        }
        
        stepCounter += 1
        let initialMessage = "In \(steps?[stepCounter].distance ?? 0) meters \(steps?[stepCounter].instructions ?? "")"
        
        lblDirection?.text = initialMessage
        
    }
    
    func getCoordinate(addressString: String, completionHandler: @escaping(CLLocationCoordinate2D, NSError?) -> Void) {
        
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(addressString) {(placemarks, error) in
            
            if error == nil {
                if let placemark = placemarks?[0] {
                    let location = placemark.location!
                    
                    completionHandler(location.coordinate, nil)
                }
            }else{
                completionHandler(kCLLocationCoordinate2DInvalid, error as NSError?)
            }
        }
    }
    
    private func configureLocationService() {
        
        locationManager.delegate = self
        
        let status = CLLocationManager.authorizationStatus()
        
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }else if status == .authorizedAlways || status == .authorizedWhenInUse{
            
            beginLocationUpdates(locationManager: locationManager)
        }
    }
    
    private func zoomToLatestLocation(with coordinate: CLLocationCoordinate2D) {
        
        let zoomRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)
        mapView?.setRegion(zoomRegion, animated: true)
    }
    
    private func beginLocationUpdates(locationManager: CLLocationManager) {
        
        mapView?.showsUserLocation = true
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
    }
    
    func tintPlaceHolder() {
        if let placeholder = txtAdress?.placeholder {
            txtAdress?.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(1)])
        }
    }
}


    
    


