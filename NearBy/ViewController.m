//
//  ViewController.m
//  NearBy
//
//  Created by Thomas Traylor on 12/6/14.
//  Copyright (c) 2014 Thomas Traylor. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ViewController.h"

#if !defined(METERS_PER_MILE)
#define METERS_PER_MILE 1609.344
#endif

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) MKLocalSearchRequest *searchRequest;
@property (nonatomic) BOOL userInteractionCausedRegionChange;
@property (nonatomic) MKMapRect currentSearchRect;
@property (nonatomic) MKCoordinateSpan currentSearchSpan;

@end

@implementation ViewController

@synthesize mapView = _mapView;
@synthesize searchBar = _searchBar;
@synthesize locationManager = _locationManager;
@synthesize searchRequest = _searchRequest;
@synthesize userInteractionCausedRegionChange = _userInteractionCausedRegionChange;
@synthesize currentSearchRect = _currentSearchRect;
@synthesize currentSearchSpan = _currentSearchSpan;

#pragma mark - Setters

- (CLLocationManager*)locationManager
{
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = (METERS_PER_MILE * 5.0);
        _locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        _locationManager.activityType = CLActivityTypeOtherNavigation;
    }
    
    return _locationManager;
}

- (MKLocalSearchRequest*)searchRequest
{
    if(_searchRequest == nil)
    {
        _searchRequest = [[MKLocalSearchRequest alloc] init];
    }
    
    return _searchRequest;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"NearBy";
    
    // get the users location    
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    
    self.mapView.delegate = self;
    self.mapView.showsBuildings = NO;
    self.mapView.pitchEnabled = YES;
    self.mapView.zoomEnabled = YES;
    self.mapView.rotateEnabled = YES;
    self.mapView.showsUserLocation = YES;
    [self.mapView removeAnnotations:self.mapView.annotations];

    self.searchBar.delegate = self;
    // if the user taps outside a text field, the keyboard will be hidden.
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    [self.view addGestureRecognizer:tapGesture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Keyboard Management

-(void)hideKeyboard
{
    [self.searchBar resignFirstResponder];
}

#pragma mark - Map Regions

- (MKMapRect)createRectForRegion:(MKCoordinateRegion)region
{
    
    MKMapPoint a = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude + region.span.latitudeDelta / 2.0,
                                                                      region.center.longitude - region.span.longitudeDelta / 2.0));
    MKMapPoint b = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta / 2.0,
                                                                      region.center.longitude + region.span.longitudeDelta / 2.0));
    
    return MKMapRectMake(MIN(a.x,b.x), MIN(a.y,b.y), ABS(a.x-b.x), ABS(a.y-b.y));
}

- (MKCoordinateRegion)createSearchRegionForLocation:(CLLocationCoordinate2D)coordinate andDistance:(CLLocationDistance)distance
{
    CLLocationDirection latInMeters = distance*METERS_PER_MILE;
    CLLocationDirection longInMeters = distance*METERS_PER_MILE;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, latInMeters, longInMeters);
    
    self.currentSearchSpan = region.span;
    self.currentSearchRect = [self createRectForRegion:region];
    
    return region;
}

- (MKCoordinateRegion)createViewableRegionForLocation:(CLLocationCoordinate2D)coordinate andDistance:(CLLocationDistance)distance
{
    CLLocationDirection latInMeters = distance*METERS_PER_MILE;
    CLLocationDirection longInMeters = distance*METERS_PER_MILE;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, latInMeters, longInMeters);
    
    return region;
}

- (MKCoordinateRegion)createNewSearchRegionForRegion:(MKCoordinateRegion)region
{
    MKCoordinateSpan span = region.span;
    if(span.latitudeDelta < self.currentSearchSpan.latitudeDelta)
    {
        // since the viewable span's latitude delta is less than
        // the search span latitude delta we'll add the diff of the two
        // to the current viewable span
        span.latitudeDelta = self.currentSearchSpan.latitudeDelta + (self.currentSearchSpan.latitudeDelta - span.latitudeDelta);
    }
    else
    {
        // since the viewable span's latitude delta is larger than the search span
        // latitude delta we'll add 50% to the viewable region
        span.latitudeDelta += (span.latitudeDelta * 0.5f);
    }
    
    if (span.longitudeDelta < self.currentSearchSpan.longitudeDelta)
    {
        // since the viewable span's longitude delta is less than
        // the search span longitude delta we'll add the diff of the two
        // to the current viewable span
        span.longitudeDelta = self.currentSearchSpan.longitudeDelta + (self.currentSearchSpan.longitudeDelta - span.longitudeDelta);
    }
    else
    {
        // since the viewable span's longitude delta is larger than the search span
        // longitude delta we'll add 50% to the viewable region
        span.longitudeDelta += (span.longitudeDelta * 0.5f);
    }
    
    MKCoordinateRegion newRegion = MKCoordinateRegionMake(region.center, span);
    self.currentSearchSpan = newRegion.span;
    self.currentSearchRect = [self createRectForRegion:newRegion];
    return newRegion;
}

#pragma mark - Local Search

- (void)localSearch
{
    MKLocalSearch *search = [[MKLocalSearch alloc]initWithRequest:self.searchRequest];
    
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
       
        if(error)
            NSLog(@"[%@ %@] error(%ld): %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (long)[error code],
                  [error localizedDescription]);
        
        if (response.mapItems.count == 0)
        {
            [self noResultsForSearch];
        }
        else
        {
            for (MKMapItem *item in response.mapItems)
            {
                // Check to see if the location is within our search region. MKLocalSearch might
                // return results that are not within the search region
                MKMapPoint mapPoint = MKMapPointForCoordinate(item.placemark.coordinate);
                if (MKMapRectContainsPoint(self.currentSearchRect, mapPoint))
                {
                    MKPointAnnotation *annotation = [[MKPointAnnotation alloc]init];
                    annotation.coordinate = item.placemark.coordinate;
                    annotation.title = item.name;
                    //NSLog(@"[%@ %@]name: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), item.name);
                    NSLog(@"[%@ %@]item: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), item);
                    [self.mapView addAnnotation:annotation];
                }
            }
            
            // see if we have any annotations, if not we'll
            // display a message
            if([[self.mapView annotations] count] == 1)
            {
                [self noResultsForSearch];
            }
        }
    }];
}

- (void)noResultsForSearch
{
    UIAlertView *noMatch = [[UIAlertView alloc] initWithTitle:@"No Matches"
                                                      message:[NSString stringWithFormat:@"%@ was not found in your area", self.searchRequest.naturalLanguageQuery]
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil, nil];
    [noMatch show];
    self.searchRequest.naturalLanguageQuery = nil;

}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // once we know where we are, we don't need to keep the location services running,
    // so stop it
    [self.locationManager stopUpdatingLocation];
    CLLocation *location = [locations lastObject];
    [self.mapView setCenterCoordinate:location.coordinate animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if(error)
        NSLog(@"[%@ %@] error(%ld): %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (long)[error code],
              [error localizedDescription]);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status)
    {
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:

            [self.locationManager startUpdatingLocation];
            break;

        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
        default:

            [self.locationManager stopUpdatingLocation];
            break;
    }
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    MKCoordinateRegion region = [self createViewableRegionForLocation:userLocation.coordinate andDistance:5.0f];
    [self.mapView setRegion:region animated:YES];
    self.searchRequest.region = [self createSearchRegionForLocation:userLocation.coordinate andDistance:20.0f];
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
    UIView* view = mapView.subviews.firstObject;
    // check to see if the user is interacting with the map
    for(UIGestureRecognizer* recognizer in view.gestureRecognizers)
    {
        if(recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateEnded)
        {
            self.userInteractionCausedRegionChange = YES;
            break;
        }
    }
}

-(void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    if(self.userInteractionCausedRegionChange)
    {
        self.userInteractionCausedRegionChange = NO;
        MKMapPoint mapPoint = MKMapPointForCoordinate(mapView.region.center);
        if (MKMapRectContainsPoint(self.currentSearchRect, mapPoint))
        {
            MKMapRect viewableRect = [self createRectForRegion:mapView.region];
            if (!MKMapRectContainsRect(self.currentSearchRect, viewableRect))
            {
                // the user has zoomed out but the viewable region's center point is still
                // within the current search map rect. We will use the current region center
                // and increase the span by some precentage to create a new search region (map rect)
                
                MKCoordinateRegion region = [self createNewSearchRegionForRegion:mapView.region];
                self.searchRequest.region = region;
                // if there is a search request query string, then
                // we'll do a search
                if (self.searchRequest.naturalLanguageQuery)
                {
                    [self localSearch];
                }
            }
        }
        else
        {
            // the user may have zoomed out, but none the less the region center is outside the
            // current search map rect. We will use the current region center and increase
            // the span by some precentage to create a new search region (map rect)

            MKCoordinateRegion region = [self createNewSearchRegionForRegion:mapView.region];
            self.searchRequest.region = region;
            // if there is a search request query string, then
            // we'll do a search
            if (self.searchRequest.naturalLanguageQuery)
            {
                [self localSearch];
            }
        }
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([searchText length] == 0)
    {
        [searchBar performSelector:@selector(resignFirstResponder)
                        withObject:nil
                        afterDelay:0];
        self.searchRequest.naturalLanguageQuery = nil;
        [self.mapView removeAnnotations:self.mapView.annotations];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    // NSLog(@"[%@ %@] search for: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), searchBar.text);
    self.searchRequest.naturalLanguageQuery = searchBar.text;
    [self localSearch];
}

@end
